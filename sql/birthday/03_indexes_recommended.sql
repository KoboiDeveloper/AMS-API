-- Optional supporting indexes (create if missing). Safe to re-run.

IF NOT EXISTS (
    SELECT 1 FROM SYS_MEMBER.sys.indexes
    WHERE name = 'IX_DT_MEMBER_VOUCHER_HBD_Tanggal'
      AND object_id = OBJECT_ID('SYS_MEMBER.dbo.DT_MEMBER_VOUCHER')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DT_MEMBER_VOUCHER_HBD_Tanggal
        ON SYS_MEMBER.dbo.DT_MEMBER_VOUCHER (CATEGORY, Tanggal_Buat)
        INCLUDE (ID_MEMBER, promocode, NilaiVoucher);
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_dt_member_birthday_valid'
      AND object_id = OBJECT_ID('dbo.dt_member')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_dt_member_birthday_valid
        ON dbo.dt_member (validasi_email, validasi_data)
        INCLUDE (ID_MEMBER, ID_MEMBER_APPS, Nama, email, TglLahir);
END
GO

IF NOT EXISTS (
    SELECT 1 FROM SYS_MEMBER.sys.indexes
    WHERE name = 'IX_DT_POS_TRANSACTION_LOG_ID_MEMBER'
      AND object_id = OBJECT_ID('SYS_MEMBER.dbo.DT_POS_TRANSACTION_LOG')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DT_POS_TRANSACTION_LOG_ID_MEMBER
        ON SYS_MEMBER.dbo.DT_POS_TRANSACTION_LOG (ID_MEMBER)
        INCLUDE (ID_STORE, GRAND_TOTAL);
END
GO
