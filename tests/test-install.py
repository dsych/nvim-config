#!/usr/bin/env python3
"""Installer regression tests: disposable HOME/repository, no dependency installs.
Run: python3 tests/test-install.py
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def snapshot(root):
    """Contents, permissions and link targets; never traverse directory symlinks."""
    result = {}
    for directory, dirs, files in os.walk(root, followlinks=False):
        for name in dirs + files:
            path = Path(directory) / name
            relative = str(path.relative_to(root))
            if path.is_symlink():
                result[relative] = ('link', os.readlink(path))
            elif path.is_file():
                result[relative] = ('file', path.stat().st_mode, path.read_bytes())
            else:
                result[relative] = ('dir', path.stat().st_mode)
    return result


class InstallTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-install-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / 'home'
        self.home.mkdir()
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        shutil.copy2(ROOT / 'install.sh', self.repo / 'install.sh')
        for name in ('init.lua', 'coc-settings.json', 'starship.toml'):
            (self.repo / name).write_text('fixture\n')
        for name in ('lua', 'kitty', 'warpd', 'lsd', 'fd', 'wezterm', 'tmux/utils', 'fish/functions', 'pi/agent/extensions'):
            (self.repo / name).mkdir(parents=True, exist_ok=True)
        (self.repo / 'tmux/tmux.conf').write_text('set -g mouse on\n')
        (self.repo / 'fish/functions/example.fish').write_text('function example; end\n')
        shutil.copytree(ROOT / 'pi/agent/extensions/ctx-inspect', self.repo / 'pi/agent/extensions/ctx-inspect')
        self.skill_src = self.repo / 'pi/agent/skills/example-skill'
        self.skill_src.mkdir(parents=True)
        (self.skill_src / 'SKILL.md').write_text('---\nname: example-skill\ndescription: fixture\n---\n')
        self.config = self.home / '.config'
        self.config.mkdir()
        self.extensions = self.home / '.pi/agent/extensions'
        self.skills = self.home / '.pi/agent/skills'
        self.tool_log = self.root / 'dependency-calls'
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        # which finds cargo, but executing any dependency tool fails and is
        # recorded. HOME/.local/source is absent, so no dependency callbacks run.
        for name in ('cargo', 'git', 'wget', 'mvn', 'jdtls'):
            tool = self.bin / name
            tool.write_text('#!/bin/sh\nprintf "%s\\n" "$0 $*" >> "$INSTALL_TOOL_LOG"\nexit 99\n')
            tool.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), PATH=f'{self.bin}:{os.environ["PATH"]}',
                        INSTALL_TOOL_LOG=str(self.tool_log))

    def run_install(self, success=True):
        p = subprocess.run(['bash', str(self.repo / 'install.sh')], cwd=self.repo,
                           env=self.env, capture_output=True, text=True, timeout=15)
        if success:
            self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        else:
            self.assertNotEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertFalse(self.tool_log.exists(), 'Installer attempted to execute a dependency tool')
        return p

    def test_refuses_tmux_directory_symlinks_before_any_changes(self):
        for target in (self.repo / 'tmux', self.root / 'missing'):
            with self.subTest(target=target):
                path = self.config / 'tmux'
                path.symlink_to(target, target_is_directory=True)
                sentinel = self.config / 'nvim/init.lua'
                sentinel.parent.mkdir(exist_ok=True)
                sentinel.write_text('do not touch\n')
                before_home, before_repo = snapshot(self.home), snapshot(self.repo)
                p = self.run_install(success=False)
                self.assertIn('is a symlink', p.stderr)
                self.assertIn(str(path), p.stderr)
                self.assertEqual(snapshot(self.home), before_home)
                self.assertEqual(snapshot(self.repo), before_repo)
                self.assertFalse(self.extensions.exists())
                path.unlink()

    def test_refuses_relative_tmux_directory_symlink(self):
        (self.config / 'tmux').symlink_to('../../repo/tmux', target_is_directory=True)
        before = snapshot(self.home)
        self.run_install(success=False)
        self.assertEqual(snapshot(self.home), before)

    def test_installs_pi_and_tmux_without_touching_machine_local_data(self):
        self.extensions.mkdir(parents=True)
        unrelated = self.extensions / 'personal.ts'
        unrelated.write_text('personal extension\n')
        settings = self.home / '.pi/agent/settings.json'
        settings.write_text('{"personal": true}\n')
        tmux = self.config / 'tmux'
        (tmux / 'plugins').mkdir(parents=True)
        (tmux / 'plugins/keep').write_text('keep plugin\n')
        (tmux / 'snippets.json').write_text('{"keep": "snippet"}\n')
        (tmux / 'hosts.json').write_text('["keep host"]\n')
        self.run_install()
        self.assertEqual((self.extensions / 'ctx-inspect').resolve(), self.repo / 'pi/agent/extensions/ctx-inspect')
        self.assertFalse((self.extensions / 'ctx-inspect.ts').exists())
        self.assertFalse(tmux.is_symlink())
        for name in ('tmux.conf', 'utils'):
            self.assertEqual((tmux / name).resolve(), self.repo / 'tmux' / name)
        self.assertEqual(unrelated.read_text(), 'personal extension\n')
        self.assertEqual(settings.read_text(), '{"personal": true}\n')
        self.assertEqual((tmux / 'plugins/keep').read_text(), 'keep plugin\n')
        self.assertEqual((tmux / 'snippets.json').read_text(), '{"keep": "snippet"}\n')
        self.assertEqual((tmux / 'hosts.json').read_text(), '["keep host"]\n')

    def test_pi_migration_and_rerun_keep_backup(self):
        self.extensions.mkdir(parents=True)
        old = self.root / 'old-ctx-inspect.ts'
        old.write_text('old extension\n')
        dest = self.extensions / 'ctx-inspect.ts'
        dest.symlink_to(old)
        self.run_install()
        self.assertEqual((self.extensions / 'ctx-inspect').resolve(), self.repo / 'pi/agent/extensions/ctx-inspect')
        self.assertFalse(dest.is_symlink())
        backup = self.home / '.pi/agent/extension-backups/ctx-inspect.ts.old'
        self.assertTrue(backup.is_symlink())
        self.assertEqual(backup.resolve(), old)
        before = snapshot(self.extensions)
        backups_before = snapshot(backup.parent)
        self.run_install()
        self.assertEqual(snapshot(self.extensions), before)
        self.assertEqual(snapshot(backup.parent), backups_before)

    def test_dangling_pi_extension_link_is_migrated(self):
        self.extensions.mkdir(parents=True)
        dest = self.extensions / 'ctx-inspect.ts'
        old = self.root / 'deleted-old-source.ts'
        dest.symlink_to(old)
        self.run_install()
        self.assertEqual((self.extensions / 'ctx-inspect').resolve(), self.repo / 'pi/agent/extensions/ctx-inspect')
        self.assertFalse(dest.is_symlink())
        self.assertEqual(os.readlink(self.home / '.pi/agent/extension-backups/ctx-inspect.ts.old'), str(old))

    def test_pi_directory_backup_is_outside_auto_discovery(self):
        old = self.extensions / 'ctx-inspect'
        old.mkdir(parents=True)
        (old / 'index.ts').write_text('old directory extension\n')
        self.run_install()
        backup = self.home / '.pi/agent/extension-backups/ctx-inspect.old'
        self.assertEqual((backup / 'index.ts').read_text(), 'old directory extension\n')
        self.assertEqual(old.resolve(), self.repo / 'pi/agent/extensions/ctx-inspect')
        self.assertEqual(sorted(p.name for p in self.extensions.iterdir()), ['ctx-inspect'])

    def test_pi_backup_conflict_is_not_overwritten(self):
        dest = self.extensions / 'ctx-inspect'
        dest.mkdir(parents=True)
        (dest / 'index.ts').write_text('existing\n')
        backup = self.home / '.pi/agent/extension-backups/ctx-inspect.old'
        backup.mkdir(parents=True)
        (backup / 'index.ts').write_text('older backup\n')
        p = self.run_install(success=False)
        self.assertIn('already exists', p.stderr)
        self.assertEqual((dest / 'index.ts').read_text(), 'existing\n')
        self.assertEqual((backup / 'index.ts').read_text(), 'older backup\n')

    def test_pi_legacy_backup_conflict_is_not_overwritten(self):
        self.extensions.mkdir(parents=True)
        dest = self.extensions / 'ctx-inspect.ts'
        dest.write_text('existing flat extension\n')
        backup = self.home / '.pi/agent/extension-backups/ctx-inspect.ts.old'
        backup.parent.mkdir(parents=True)
        backup.write_text('older backup\n')
        p = self.run_install(success=False)
        self.assertIn('already exists', p.stderr)
        self.assertEqual(dest.read_text(), 'existing flat extension\n')
        self.assertEqual(backup.read_text(), 'older backup\n')
        self.assertFalse((self.extensions / 'ctx-inspect').exists())

    def test_pi_skills_link_and_keep_other_skills(self):
        self.skills.mkdir(parents=True)
        private = self.skills / 'private-skill'
        private.mkdir()
        (private / 'SKILL.md').write_text('private\n')
        self.run_install()
        self.assertEqual((self.skills / 'example-skill').resolve(), self.skill_src)
        self.assertEqual((private / 'SKILL.md').read_text(), 'private\n')
        before = snapshot(self.skills)
        self.run_install()
        self.assertEqual(snapshot(self.skills), before)
        self.assertFalse((self.home / '.pi/agent/skill-backups').exists())

    def test_pi_skill_backup_is_outside_auto_discovery(self):
        old_link = self.skills / 'example-skill'
        self.skills.mkdir(parents=True)
        old_target = self.root / 'moved-away/example-skill'
        old_link.symlink_to(old_target, target_is_directory=True)
        self.run_install()
        self.assertEqual(old_link.resolve(), self.skill_src)
        backup = self.home / '.pi/agent/skill-backups/example-skill.old'
        self.assertEqual(os.readlink(backup), str(old_target))
        self.assertEqual(sorted(p.name for p in self.skills.iterdir()), ['example-skill'])

    def test_tmux_hosts_migrate_from_existing_utils_directory(self):
        tmux = self.config / 'tmux'
        (tmux / 'utils').mkdir(parents=True)
        (tmux / 'utils/hosts.json').write_text('["legacy host"]\n')
        self.run_install()
        self.assertEqual((tmux / 'hosts.json').read_text(), '["legacy host"]\n')
        self.assertEqual((tmux / 'utils.old/hosts.json').read_text(), '["legacy host"]\n')
        self.assertTrue((tmux / 'utils').is_symlink())
        self.assertFalse(tmux.is_symlink())


if __name__ == '__main__':
    unittest.main(verbosity=2)
