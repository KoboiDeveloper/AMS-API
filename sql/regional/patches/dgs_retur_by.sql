/*
  Tambah kolom RETUR_BY di TR_PRASALES_DETAIL + update SP retur/getrows.
  Idempotent. Tidak menghapus kolom / data existing.
  SQL Server 2016 RTM: CREATE OR ALTER tidak tersedia → recreate SP via DROP+CREATE
  (hanya definisi SP diganti; data tabel tetap).
  Jalankan di pos_server.
*/
USE pos_server;
GO
SET NOCOUNT ON;
GO

IF COL_LENGTH('dbo.TR_PRASALES_DETAIL', 'RETUR_BY') IS NULL
BEGIN
    ALTER TABLE dbo.TR_PRASALES_DETAIL ADD RETUR_BY varchar(80) NULL;
END;
GO

IF OBJECT_ID(N'dbo.xsp_get_ar_confirmation_retur_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_get_ar_confirmation_retur_update;
GO
CREATE PROCEDURE dbo.xsp_get_ar_confirmation_retur_update
(
      @p_id               int
    , @p_keterangan_retur varchar(100)
    , @p_retur_by         varchar(80) = NULL
)
AS
BEGIN
    UPDATE dbo.TR_PRASALES_DETAIL
       SET status = 9,
           TANGGAL_RETUR = GETDATE(),
           KETERANGAN_ADMIN = @p_keterangan_retur,
           RETUR_BY = COALESCE(NULLIF(LTRIM(RTRIM(@p_retur_by)), ''), RETUR_BY)
     WHERE NO_URUT = @p_id;
END;
GO

IF OBJECT_ID(N'dbo.xsp_get_ar_confirmation_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_get_ar_confirmation_getrows;
GO
CREATE PROCEDURE dbo.xsp_get_ar_confirmation_getrows
(
    @p_id_prasales varchar(50)
)
AS
BEGIN
    DECLARE @status int;
    SET @status = (
        SELECT STATUS_TRANSAKSI
        FROM dbo.TR_PRASALES_HEADER
        WHERE ID_PRASALES_HEADER = @p_id_prasales
    );

    SELECT
          @status AS status_header
        , B.NO_URUT
        , B.PLU
        , B.QTY
        , B.NET
        , CASE
              WHEN B.STATUS = 0 THEN 'NEW'
              WHEN B.STATUS = 1 THEN 'APPROVED'
              WHEN B.STATUS IN (2, 9) THEN 'RETUR'
          END AS STATUS
        , CASE
              WHEN B.STATUS = 0 THEN 'default'
              WHEN B.STATUS = 1 THEN 'success'
              WHEN B.STATUS IN (2, 9) THEN 'warning'
          END AS label_info
        , C.DESKRIPSI
        , CASE
              WHEN B.KETERANGAN_ADMIN IS NULL THEN ''
              ELSE 'note retur: ' + '<strong>' + B.KETERANGAN_ADMIN + '</strong>'
          END AS KETERANGAN_ADMIN
        , B.RETUR_BY
    FROM dbo.TR_PRASALES_HEADER AS A
    INNER JOIN dbo.TR_PRASALES_DETAIL AS B ON B.ID_PRASALES_HEADER = A.ID_PRASALES_HEADER
    LEFT OUTER JOIN dbo.dt_plu AS C ON C.PLU = B.PLU
    WHERE A.ID_PRASALES_HEADER = @p_id_prasales;
END;
GO

PRINT 'dgs_retur_by.sql completed.';
GO
