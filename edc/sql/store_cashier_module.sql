-- Optional RBAC seed: kasir module for STORE_LOGIN header menu
-- Adjust schema/table names to match your RBAC SP / tables.

/*
Example (pseudo — run via your admin RBAC UI or adapt to dbo.RBAC_*):

INSERT INTO modules (module_code, module_name, endpoint_path, ...)
VALUES ('STORE_CASHIER', 'Kasir', '/store/cashier', ...);

-- Assign to role STORE_LOGIN via role-permissions.
*/
