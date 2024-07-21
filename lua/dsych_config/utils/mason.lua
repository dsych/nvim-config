local M = {}

M.get_package_path_with_fallback = function (mason_package_name, mason_suffix, fallback_path)
    local package_installed, package_installation = pcall(require"mason-registry".get_package, mason_package_name)
    if package_installed then
        return vim.fn.glob(package_installation:get_install_path() .. mason_suffix)
    else
        return fallback_path and vim.fn.glob(fallback_path) or ""
    end
end

return M
