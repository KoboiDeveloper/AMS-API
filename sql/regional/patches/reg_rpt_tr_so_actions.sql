/*
  Tr So modal actions (REG2) — ASP parity:
    DETAIL         → Rpt_Tr_So_Detail.aspx       (FULL / DEPT / CLASS)
    SELISIH        → Rpt_Tr_So_Detail_Selisih.aspx (ALL|FIX × FULL|DEPT|CLASS)
    GAWANG         → Chk_Gawang_G_sum.aspx
    DETAIL GAWANG  → Chk_Gawang_G.aspx
    PLU GAWANG     → Chk_Gawang.aspx
  Store for modals comes from row ID_STORE_SO (not Shared.IDSTORE).
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

/* ---------- DETAIL ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_tr_so_detail_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_detail_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_detail_getrows
(
      @p_id varchar(80)
    , @p_id_store varchar(50) = NULL
    , @p_tipe varchar(50) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @hdr varchar(80) = LTRIM(RTRIM(ISNULL(@p_id, '')));
        DECLARE @store varchar(50) = LTRIM(RTRIM(ISNULL(@p_id_store, '')));
        DECLARE @tipe varchar(20) = UPPER(LTRIM(RTRIM(ISNULL(@p_tipe, 'FULL'))));
        IF @tipe IN ('','ALL','PLU') SET @tipe = 'FULL';
        IF @hdr = '' OR @store = ''
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'NO_TR_SO_HEADER dan id_store wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        IF @tipe IN ('DEPT','CLASS')
        BEGIN
            CREATE TABLE #dg (
                plu varchar(13) NULL,
                deskripsi varchar(max) NULL,
                qty_data int NULL,
                PRICE_data money NULL,
                HPP_A money NULL,
                TOTAL_HPP_A money NULL,
                TOTAL_PRICE_DATA money NULL,
                QTY_REAL int NULL,
                PRICE_A money NULL,
                HPP_REAL money NULL,
                TOTAL_HPP_REAL money NULL,
                total_PRICE_A money NULL,
                qty_selisih int NULL,
                PRICE_SELISIH money NULL,
                total_hpp_selisih money NULL,
                total_price_selisih money NULL
            );
            IF @tipe = 'DEPT'
                INSERT INTO #dg EXEC pos_server.dbo.xsp_rpt_tr_so_detail_dept_getrows @p_tr_so_header=@hdr, @p_id_store=@store;
            ELSE
                INSERT INTO #dg EXEC pos_server.dbo.xsp_rpt_tr_so_detail_class_getrows @p_tr_so_header=@hdr, @p_id_store=@store;

            SELECT @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT
                               d.plu AS PLU,
                               d.deskripsi AS DESKRIPSI,
                               CAST(ISNULL(d.qty_data,0) AS float) AS QTY_DATA,
                               CAST(ISNULL(d.PRICE_data,0) AS float) AS PRICE_DATA,
                               CAST(ISNULL(d.TOTAL_PRICE_DATA,0) AS float) AS TOTAL_PRICE_DATA,
                               CAST(ISNULL(d.QTY_REAL,0) AS float) AS QTY_REAL,
                               CAST(ISNULL(d.PRICE_A,0) AS float) AS PRICE_A,
                               CAST(ISNULL(d.total_PRICE_A,0) AS float) AS TOTAL_PRICE_A,
                               CAST(ISNULL(d.qty_selisih,0) AS float) AS QTY_SELISIH,
                               CAST(ISNULL(d.PRICE_SELISIH,0) AS float) AS PRICE_SELISIH,
                               CAST(ISNULL(d.total_price_selisih,0) AS float) AS TOTAL_PRICE_SELISIH
                           FROM #dg d
                           ORDER BY d.plu
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        CREATE TABLE #df (
            NO_TR_SO_HEADER varchar(32) NULL,
            ID_TR_SO_DETAIL varchar(32) NULL,
            PLU varchar(13) NULL,
            Deskripsi varchar(max) NULL,
            qty_data int NULL,
            PRICE_data money NULL,
            HPP_A money NULL,
            TOTAL_HPP_A money NULL,
            TOTAL_PRICE_DATA money NULL,
            QTY_REAL int NULL,
            PRICE_A money NULL,
            HPP_REAL money NULL,
            TOTAL_HPP_REAL money NULL,
            total_PRICE_A money NULL,
            QTY_SELISIH int NULL,
            PRICE_SELISIH money NULL,
            TOTAL_HPP_SELISIH money NULL,
            TOTAL_PRICE_SELISIH money NULL
        );
        INSERT INTO #df EXEC pos_server.dbo.xsp_rpt_tr_so_detail_getrows @p_tr_so_header=@hdr, @p_id_store=@store;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           d.PLU AS PLU,
                           d.Deskripsi AS DESKRIPSI,
                           CAST(ISNULL(d.qty_data,0) AS float) AS QTY_DATA,
                           CAST(ISNULL(d.PRICE_data,0) AS float) AS PRICE_DATA,
                           CAST(ISNULL(d.TOTAL_PRICE_DATA,0) AS float) AS TOTAL_PRICE_DATA,
                           CAST(ISNULL(d.QTY_REAL,0) AS float) AS QTY_REAL,
                           CAST(ISNULL(d.PRICE_A,0) AS float) AS PRICE_A,
                           CAST(ISNULL(d.total_PRICE_A,0) AS float) AS TOTAL_PRICE_A,
                           CAST(ISNULL(d.QTY_SELISIH,0) AS float) AS QTY_SELISIH,
                           CAST(ISNULL(d.PRICE_SELISIH,0) AS float) AS PRICE_SELISIH,
                           CAST(ISNULL(d.TOTAL_PRICE_SELISIH,0) AS float) AS TOTAL_PRICE_SELISIH
                       FROM #df d
                       ORDER BY d.PLU
                       FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---------- SELISIH ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_tr_so_selisih_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_selisih_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_selisih_getrows
(
      @p_id varchar(80)
    , @p_tipe varchar(50) = NULL
    , @p_status varchar(50) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @hdr varchar(80) = LTRIM(RTRIM(ISNULL(@p_id, '')));
        DECLARE @tipe varchar(20) = UPPER(LTRIM(RTRIM(ISNULL(@p_tipe, 'FULL'))));
        DECLARE @mode varchar(20) = UPPER(LTRIM(RTRIM(ISNULL(@p_status, 'ALL'))));
        IF @tipe IN ('','ALL','PLU') SET @tipe = 'FULL';
        IF @mode IN ('','0') SET @mode = 'ALL';
        IF @mode IN ('FIX','NONZERO','GAKNOL','!=0') SET @mode = 'FIX';
        IF @hdr = ''
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'NO_TR_SO_HEADER wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        /* DEPT / CLASS (ALL or FIX) — no no_tr_so_header column */
        IF @tipe IN ('DEPT','CLASS')
        BEGIN
            CREATE TABLE #sg (
                brand varchar(20) NULL,
                store varchar(20) NULL,
                plu varchar(13) NULL,
                qty_selisih int NULL,
                hpp_selisih money NULL,
                price_selisih money NULL,
                total_hpp_selisih money NULL,
                total_price_selisih money NULL,
                qty_adj int NULL,
                hpp_adj money NULL,
                price_adj money NULL,
                total_hpp_adj money NULL,
                total_price_adj money NULL
            );
            IF @mode = 'FIX' AND @tipe = 'DEPT'
                INSERT INTO #sg EXEC pos_server.dbo.xsp_rpt_tr_so_detail_selisih_gakNol_DEPT_getrows @p_tr_so_header=@hdr;
            ELSE IF @mode = 'FIX' AND @tipe = 'CLASS'
                INSERT INTO #sg EXEC pos_server.dbo.xsp_rpt_tr_so_detail_selisih_gakNol_CLASS_getrows @p_tr_so_header=@hdr;
            ELSE IF @tipe = 'DEPT'
                INSERT INTO #sg EXEC pos_server.dbo.xsp_rpt_tr_so_detail_selisih_DEPT_getrows @p_tr_so_header=@hdr;
            ELSE
                INSERT INTO #sg EXEC pos_server.dbo.xsp_rpt_tr_so_detail_selisih_class_getrows @p_tr_so_header=@hdr;

            SELECT @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT
                               s.plu AS PLU,
                               CAST(ISNULL(s.qty_selisih,0) AS float) AS QTY_SELISIH,
                               CAST(ISNULL(s.hpp_selisih,0) AS float) AS HPP_SELISIH,
                               CAST(ISNULL(s.price_selisih,0) AS float) AS PRICE_SELISIH,
                               CAST(ISNULL(s.total_hpp_selisih,0) AS float) AS TOTAL_HPP_SELISIH,
                               CAST(ISNULL(s.total_price_selisih,0) AS float) AS TOTAL_PRICE_SELISIH,
                               CAST(ISNULL(s.qty_adj,0) AS float) AS QTY_ADJ,
                               CAST(ISNULL(s.hpp_adj,0) AS float) AS HPP_ADJ,
                               CAST(ISNULL(s.price_adj,0) AS float) AS PRICE_ADJ,
                               CAST(ISNULL(s.total_hpp_adj,0) AS float) AS TOTAL_HPP_ADJ,
                               CAST(ISNULL(s.total_price_adj,0) AS float) AS TOTAL_PRICE_ADJ
                           FROM #sg s
                           ORDER BY s.plu
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        /* FULL — has no_tr_so_header */
        CREATE TABLE #sf (
            brand varchar(20) NULL,
            store varchar(20) NULL,
            no_tr_so_header varchar(32) NULL,
            plu varchar(13) NULL,
            qty_selisih int NULL,
            hpp_selisih money NULL,
            price_selisih money NULL,
            total_hpp_selisih money NULL,
            total_price_selisih money NULL,
            qty_adj int NULL,
            hpp_adj money NULL,
            price_adj money NULL,
            total_hpp_adj money NULL,
            total_price_adj money NULL
        );
        IF @mode = 'FIX'
            INSERT INTO #sf EXEC pos_server.dbo.xsp_rpt_tr_so_detail_selisih_gakNol_getrows @p_tr_so_header=@hdr;
        ELSE
            INSERT INTO #sf EXEC pos_server.dbo.xsp_rpt_tr_so_detail_selisih_getrows @p_tr_so_header=@hdr;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           s.plu AS PLU,
                           CAST(ISNULL(s.qty_selisih,0) AS float) AS QTY_SELISIH,
                           CAST(ISNULL(s.hpp_selisih,0) AS float) AS HPP_SELISIH,
                           CAST(ISNULL(s.price_selisih,0) AS float) AS PRICE_SELISIH,
                           CAST(ISNULL(s.total_hpp_selisih,0) AS float) AS TOTAL_HPP_SELISIH,
                           CAST(ISNULL(s.total_price_selisih,0) AS float) AS TOTAL_PRICE_SELISIH,
                           CAST(ISNULL(s.qty_adj,0) AS float) AS QTY_ADJ,
                           CAST(ISNULL(s.hpp_adj,0) AS float) AS HPP_ADJ,
                           CAST(ISNULL(s.price_adj,0) AS float) AS PRICE_ADJ,
                           CAST(ISNULL(s.total_hpp_adj,0) AS float) AS TOTAL_HPP_ADJ,
                           CAST(ISNULL(s.total_price_adj,0) AS float) AS TOTAL_PRICE_ADJ
                       FROM #sf s
                       ORDER BY s.plu
                       FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---------- GAWANG (sum) ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_tr_so_gawang_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_gawang_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_gawang_getrows
(
      @p_id varchar(80)
    , @p_id_store varchar(50) = NULL
    , @p_article varchar(80) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @hdr varchar(80) = LTRIM(RTRIM(ISNULL(@p_id, '')));
        DECLARE @store varchar(50) = LTRIM(RTRIM(ISNULL(@p_id_store, '')));
        DECLARE @gawang varchar(80) = LTRIM(RTRIM(ISNULL(@p_article, '')));
        IF @hdr = '' OR @store = ''
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'NO_TR_SO_HEADER dan id_store wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        CREATE TABLE #g (
            GAWANG varchar(max) NULL,
            TOTAL_QTY int NULL
        );

        INSERT INTO #g
        EXEC pos_server.dbo.XSP_gawang_detail_gawang_sum_GETROWS
            @p_id_store = @store,
            @p_gawang = @gawang,
            @p_id_tr_so_header = @hdr;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           g.GAWANG AS GAWANG,
                           CAST(ISNULL(g.TOTAL_QTY,0) AS float) AS TOTAL_QTY
                       FROM #g g
                       ORDER BY g.GAWANG
                       FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---------- DETAIL GAWANG ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_tr_so_gawang_detail_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_gawang_detail_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_gawang_detail_getrows
(
      @p_id varchar(80)
    , @p_id_store varchar(50) = NULL
    , @p_article varchar(80) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @hdr varchar(80) = LTRIM(RTRIM(ISNULL(@p_id, '')));
        DECLARE @store varchar(50) = LTRIM(RTRIM(ISNULL(@p_id_store, '')));
        DECLARE @gawang varchar(80) = LTRIM(RTRIM(ISNULL(@p_article, '')));
        IF @hdr = '' OR @store = ''
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'NO_TR_SO_HEADER dan id_store wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        CREATE TABLE #gd (
            GAWANG varchar(max) NULL,
            PLU varchar(13) NULL,
            DESKRIPSI varchar(max) NULL,
            QTY_REAL int NULL,
            HPP_REAL money NULL,
            PRICE_REAL money NULL,
            TOTAL_HPP_REAL money NULL,
            TOTAL_PRICE_REAL money NULL
        );

        INSERT INTO #gd
        EXEC pos_server.dbo.XSP_gawang_detail_gawang_GETROWS
            @p_id_store = @store,
            @p_gawang = @gawang,
            @p_id_tr_so_header = @hdr;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           g.GAWANG AS GAWANG,
                           g.PLU AS PLU,
                           g.DESKRIPSI AS DESKRIPSI,
                           CAST(ISNULL(g.QTY_REAL,0) AS float) AS QTY_REAL,
                           CAST(ISNULL(g.PRICE_REAL,0) AS float) AS PRICE_REAL,
                           CAST(ISNULL(g.TOTAL_PRICE_REAL,0) AS float) AS TOTAL_PRICE_REAL
                       FROM #gd g
                       ORDER BY g.GAWANG, g.PLU
                       FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---------- PLU GAWANG ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_tr_so_gawang_plu_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_gawang_plu_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_gawang_plu_getrows
(
      @p_id varchar(80)
    , @p_id_store varchar(50) = NULL
    , @p_plu varchar(80) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @hdr varchar(80) = LTRIM(RTRIM(ISNULL(@p_id, '')));
        DECLARE @store varchar(50) = LTRIM(RTRIM(ISNULL(@p_id_store, '')));
        DECLARE @plu varchar(80) = LTRIM(RTRIM(ISNULL(@p_plu, '')));
        IF @hdr = '' OR @store = ''
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'NO_TR_SO_HEADER dan id_store wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        CREATE TABLE #gp (
            WAKTU_URUT datetime NULL,
            NO_TR_SO_HEADER varchar(32) NULL,
            ID_TR_SO_DETAIL2 varchar(32) NULL,
            GAWANG varchar(max) NULL,
            PLU varchar(13) NULL,
            DESKRIPSI varchar(max) NULL,
            QTY_REAL int NULL,
            HPP_REAL money NULL,
            PRICE_REAL money NULL,
            TOTAL_HPP_REAL money NULL,
            TOTAL_PRICE_REAL money NULL
        );

        INSERT INTO #gp
        EXEC pos_server.dbo.XSP_gawang_detail_GETROWS
            @p_plu = @plu,
            @p_id_store = @store,
            @p_id_tr_so_header = @hdr;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           g.PLU AS PLU,
                           g.GAWANG AS GAWANG,
                           g.DESKRIPSI AS DESKRIPSI,
                           CAST(ISNULL(g.QTY_REAL,0) AS float) AS QTY_REAL,
                           CAST(ISNULL(g.PRICE_REAL,0) AS float) AS PRICE_REAL,
                           CAST(ISNULL(g.TOTAL_PRICE_REAL,0) AS float) AS TOTAL_PRICE_REAL
                       FROM #gp g
                       ORDER BY g.WAKTU_URUT, g.PLU, g.GAWANG
                       FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
