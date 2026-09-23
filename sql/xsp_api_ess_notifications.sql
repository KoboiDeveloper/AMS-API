/*
  ESS Push Notification - SQL Server (RBACESS)
  Table + SP: subscribe / histori drawer / insert / read
*/

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.ESS_USER_PUSH_SUBSCRIPTIONS', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ESS_USER_PUSH_SUBSCRIPTIONS
    (
         ID             BIGINT IDENTITY(1,1) NOT NULL
        ,NIK            VARCHAR(50)      NOT NULL
        ,ENDPOINT       NVARCHAR(MAX)    NOT NULL
        ,ENDPOINT_HASH  AS CONVERT(CHAR(64), HASHBYTES('SHA2_256', CONVERT(VARBINARY(MAX), ENDPOINT)), 2) PERSISTED
        ,P256DH         NVARCHAR(255)    NOT NULL
        ,AUTH           NVARCHAR(255)    NOT NULL
        ,USER_AGENT     NVARCHAR(255)    NULL
        ,CREATED_AT     DATETIME2(0)     NOT NULL
            CONSTRAINT DF_ESS_PUSH_SUB_CREATED DEFAULT (DATEADD(HOUR, 7, SYSUTCDATETIME()))
        ,UPDATED_AT     DATETIME2(0)     NOT NULL
            CONSTRAINT DF_ESS_PUSH_SUB_UPDATED DEFAULT (DATEADD(HOUR, 7, SYSUTCDATETIME()))
        ,CONSTRAINT PK_ESS_USER_PUSH_SUBSCRIPTIONS PRIMARY KEY CLUSTERED (ID)
        ,CONSTRAINT UQ_ESS_USER_PUSH_SUBSCRIPTIONS_ENDPOINT UNIQUE (ENDPOINT_HASH)
    );

    CREATE NONCLUSTERED INDEX IX_ESS_USER_PUSH_SUBSCRIPTIONS_NIK
        ON dbo.ESS_USER_PUSH_SUBSCRIPTIONS (NIK)
        INCLUDE (P256DH, AUTH, UPDATED_AT);
END
GO

IF OBJECT_ID(N'dbo.ESS_NOTIFICATIONS', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ESS_NOTIFICATIONS
    (
         ID             BIGINT IDENTITY(1,1) NOT NULL
        ,NIK            VARCHAR(50)      NOT NULL
        ,SENDER_NIK     VARCHAR(50)      NULL
        ,CATEGORY       VARCHAR(50)      NOT NULL
        ,TITLE          NVARCHAR(255)    NOT NULL
        ,BODY           NVARCHAR(MAX)    NOT NULL
        ,TARGET_URL     NVARCHAR(255)    NOT NULL
        ,IS_READ        BIT              NOT NULL
            CONSTRAINT DF_ESS_NOTIF_IS_READ DEFAULT (0)
        ,READ_AT        DATETIME2(0)     NULL
        ,METADATA       NVARCHAR(MAX)    NULL
        ,CREATED_AT     DATETIME2(0)     NOT NULL
            CONSTRAINT DF_ESS_NOTIF_CREATED DEFAULT (DATEADD(HOUR, 7, SYSUTCDATETIME()))
        ,CONSTRAINT PK_ESS_NOTIFICATIONS PRIMARY KEY CLUSTERED (ID)
    );

    CREATE NONCLUSTERED INDEX IX_ESS_NOTIFICATIONS_RECIPIENT
        ON dbo.ESS_NOTIFICATIONS (NIK, IS_READ, CREATED_AT DESC);
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_push_subscribe
(
     @p_nik        VARCHAR(50)
    ,@p_endpoint   NVARCHAR(MAX)
    ,@p_p256dh     NVARCHAR(255)
    ,@p_auth       NVARCHAR(255)
    ,@p_user_agent NVARCHAR(255) = NULL
    ,@bitparam     VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @p_nik = NULLIF(LTRIM(RTRIM(@p_nik)), '');
        SET @p_endpoint = NULLIF(LTRIM(RTRIM(@p_endpoint)), '');
        SET @p_p256dh = NULLIF(LTRIM(RTRIM(@p_p256dh)), '');
        SET @p_auth = NULLIF(LTRIM(RTRIM(@p_auth)), '');

        IF @p_nik IS NULL OR @p_endpoint IS NULL OR @p_p256dh IS NULL OR @p_auth IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4000001' AS responseCode, 'nik, endpoint, p256dh, and auth are required' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @now DATETIME2(0) = DATEADD(HOUR, 7, SYSUTCDATETIME());
        DECLARE @hash CHAR(64) = CONVERT(CHAR(64), HASHBYTES('SHA2_256', CONVERT(VARBINARY(MAX), @p_endpoint)), 2);
        DECLARE @id BIGINT;

        UPDATE dbo.ESS_USER_PUSH_SUBSCRIPTIONS
        SET
             NIK = @p_nik
            ,ENDPOINT = @p_endpoint
            ,P256DH = @p_p256dh
            ,AUTH = @p_auth
            ,USER_AGENT = @p_user_agent
            ,UPDATED_AT = @now
        WHERE ENDPOINT_HASH = @hash;

        IF @@ROWCOUNT = 0
        BEGIN
            INSERT INTO dbo.ESS_USER_PUSH_SUBSCRIPTIONS (NIK, ENDPOINT, P256DH, AUTH, USER_AGENT, CREATED_AT, UPDATED_AT)
            VALUES (@p_nik, @p_endpoint, @p_p256dh, @p_auth, @p_user_agent, @now, @now);
            SET @id = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            SELECT @id = ID
            FROM dbo.ESS_USER_PUSH_SUBSCRIPTIONS
            WHERE ENDPOINT_HASH = @hash;
        END;

        SET @bitparam = (
            SELECT
                 '2002500' AS responseCode
                ,'subscribed' AS responseMessage
                ,JSON_QUERY((
                    SELECT @id AS id, @p_nik AS nik
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (
            SELECT
                 '5002500' AS responseCode
                ,'Failed to save push subscription' AS responseMessage
                ,ERROR_MESSAGE() AS errorDetail
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_push_unsubscribe
(
     @p_endpoint NVARCHAR(MAX)
    ,@p_nik      VARCHAR(50) = NULL
    ,@bitparam   VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @p_endpoint = NULLIF(LTRIM(RTRIM(@p_endpoint)), '');
    SET @p_nik = NULLIF(LTRIM(RTRIM(@p_nik)), '');

    IF @p_endpoint IS NULL
    BEGIN
        SET @bitparam = (
            SELECT '4000001' AS responseCode, 'endpoint is required' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END;

    DECLARE @hash CHAR(64) = CONVERT(CHAR(64), HASHBYTES('SHA2_256', CONVERT(VARBINARY(MAX), @p_endpoint)), 2);

    DELETE FROM dbo.ESS_USER_PUSH_SUBSCRIPTIONS
    WHERE ENDPOINT_HASH = @hash
      AND (@p_nik IS NULL OR NIK = @p_nik);

    SET @bitparam = (
        SELECT
             '2002500' AS responseCode
            ,'unsubscribed' AS responseMessage
            ,JSON_QUERY((
                SELECT @@ROWCOUNT AS deleted
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )) AS data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_push_subscriptions_getrows
(
     @p_nik    VARCHAR(50)
    ,@bitparam VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @p_nik = NULLIF(LTRIM(RTRIM(@p_nik)), '');
    IF @p_nik IS NULL
    BEGIN
        SET @bitparam = (
            SELECT '4000001' AS responseCode, 'nik is required' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END;

    SET @bitparam = (
        SELECT
             '2002500' AS responseCode
            ,'OK' AS responseMessage
            ,JSON_QUERY(ISNULL((
                SELECT
                     s.ID AS id
                    ,s.NIK AS nik
                    ,s.ENDPOINT AS endpoint
                    ,s.P256DH AS p256dh
                    ,s.AUTH AS auth
                FROM dbo.ESS_USER_PUSH_SUBSCRIPTIONS s
                WHERE s.NIK = @p_nik
                FOR JSON PATH
            ), '[]')) AS data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_notification_insert
(
     @p_nik        VARCHAR(50)
    ,@p_sender_nik VARCHAR(50)   = NULL
    ,@p_category   VARCHAR(50)
    ,@p_title      NVARCHAR(255)
    ,@p_body       NVARCHAR(MAX)
    ,@p_target_url NVARCHAR(255)
    ,@p_metadata   NVARCHAR(MAX) = NULL
    ,@bitparam     VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @p_nik = NULLIF(LTRIM(RTRIM(@p_nik)), '');
        SET @p_category = NULLIF(LTRIM(RTRIM(@p_category)), '');
        SET @p_title = NULLIF(LTRIM(RTRIM(@p_title)), '');
        SET @p_body = NULLIF(LTRIM(RTRIM(@p_body)), '');
        SET @p_target_url = NULLIF(LTRIM(RTRIM(@p_target_url)), '');
        SET @p_sender_nik = NULLIF(LTRIM(RTRIM(@p_sender_nik)), '');

        IF @p_nik IS NULL OR @p_category IS NULL OR @p_title IS NULL OR @p_body IS NULL OR @p_target_url IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4000001' AS responseCode, 'nik, category, title, body, and target_url are required' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        INSERT INTO dbo.ESS_NOTIFICATIONS
            (NIK, SENDER_NIK, CATEGORY, TITLE, BODY, TARGET_URL, METADATA, IS_READ, CREATED_AT)
        VALUES
            (@p_nik, @p_sender_nik, @p_category, @p_title, @p_body, @p_target_url, @p_metadata, 0, DATEADD(HOUR, 7, SYSUTCDATETIME()));

        DECLARE @id BIGINT = SCOPE_IDENTITY();

        SET @bitparam = (
            SELECT
                 '2002500' AS responseCode
                ,'ok' AS responseMessage
                ,JSON_QUERY((
                    SELECT @id AS id
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (
            SELECT
                 '5002500' AS responseCode
                ,'Failed to insert notification' AS responseMessage
                ,ERROR_MESSAGE() AS errorDetail
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_notification_getrows
(
     @p_nik         VARCHAR(50)
    ,@p_page        INT = 1
    ,@p_limit       INT = 20
    ,@p_unread_only BIT = 0
    ,@bitparam      VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @p_nik = NULLIF(LTRIM(RTRIM(@p_nik)), '');
    IF @p_nik IS NULL
    BEGIN
        SET @bitparam = (
            SELECT '4000001' AS responseCode, 'nik is required' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END;

    IF @p_page IS NULL OR @p_page < 1 SET @p_page = 1;
    IF @p_limit IS NULL OR @p_limit < 1 SET @p_limit = 20;
    IF @p_limit > 100 SET @p_limit = 100;
    IF @p_unread_only IS NULL SET @p_unread_only = 0;

    DECLARE @offset INT = (@p_page - 1) * @p_limit;
    DECLARE @unread INT = (
        SELECT COUNT(1)
        FROM dbo.ESS_NOTIFICATIONS
        WHERE NIK = @p_nik AND IS_READ = 0
    );

    SET @bitparam = (
        SELECT
             '2002500' AS responseCode
            ,'OK' AS responseMessage
            ,JSON_QUERY((
                SELECT
                     @unread AS unread_count
                    ,JSON_QUERY(ISNULL((
                        SELECT
                             n.ID AS id
                            ,n.CATEGORY AS category
                            ,n.TITLE AS title
                            ,n.BODY AS body
                            ,n.TARGET_URL AS target_url
                            ,CAST(n.IS_READ AS BIT) AS is_read
                            ,CONVERT(VARCHAR(19), n.CREATED_AT, 126) AS created_at
                            ,n.METADATA AS metadata
                        FROM dbo.ESS_NOTIFICATIONS n
                        WHERE n.NIK = @p_nik
                          AND (@p_unread_only = 0 OR n.IS_READ = 0)
                        ORDER BY n.CREATED_AT DESC
                        OFFSET @offset ROWS FETCH NEXT @p_limit ROWS ONLY
                        FOR JSON PATH
                    ), '[]')) AS items
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )) AS data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_notification_read
(
     @p_id     BIGINT
    ,@p_nik    VARCHAR(50)
    ,@bitparam VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @p_nik = NULLIF(LTRIM(RTRIM(@p_nik)), '');
    IF @p_id IS NULL OR @p_id <= 0 OR @p_nik IS NULL
    BEGIN
        SET @bitparam = (
            SELECT '4000001' AS responseCode, 'id and nik are required' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END;

    UPDATE dbo.ESS_NOTIFICATIONS
    SET
         IS_READ = 1
        ,READ_AT = DATEADD(HOUR, 7, SYSUTCDATETIME())
    WHERE ID = @p_id
      AND NIK = @p_nik
      AND IS_READ = 0;

    IF @@ROWCOUNT = 0 AND NOT EXISTS (
        SELECT 1 FROM dbo.ESS_NOTIFICATIONS WHERE ID = @p_id AND NIK = @p_nik
    )
    BEGIN
        SET @bitparam = (
            SELECT '4040000' AS responseCode, 'Notification not found' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END;

    SET @bitparam = (
        SELECT '2002500' AS responseCode, 'ok' AS responseMessage
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_notification_read_all
(
     @p_nik    VARCHAR(50)
    ,@bitparam VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @p_nik = NULLIF(LTRIM(RTRIM(@p_nik)), '');
    IF @p_nik IS NULL
    BEGIN
        SET @bitparam = (
            SELECT '4000001' AS responseCode, 'nik is required' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END;

    UPDATE dbo.ESS_NOTIFICATIONS
    SET
         IS_READ = 1
        ,READ_AT = DATEADD(HOUR, 7, SYSUTCDATETIME())
    WHERE NIK = @p_nik
      AND IS_READ = 0;

    SET @bitparam = (
        SELECT
             '2002500' AS responseCode
            ,'ok' AS responseMessage
            ,JSON_QUERY((
                SELECT @@ROWCOUNT AS updated
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )) AS data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_user_nik_by_email
(
     @p_email  NVARCHAR(150)
    ,@bitparam VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @p_email = NULLIF(LTRIM(RTRIM(@p_email)), '');
    IF @p_email IS NULL
    BEGIN
        SET @bitparam = (
            SELECT '4000001' AS responseCode, 'email is required' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END;

    DECLARE @nik VARCHAR(50) = NULL;

    IF OBJECT_ID(N'dbo.WEB_USER_MAIN', N'U') IS NOT NULL
    BEGIN
        SELECT TOP 1
            @nik = COALESCE(NULLIF(LTRIM(RTRIM(NIK)), ''), NULLIF(LTRIM(RTRIM(ID_USER)), ''))
        FROM dbo.WEB_USER_MAIN
        WHERE LOWER(LTRIM(RTRIM(EMAIL))) = LOWER(@p_email);
    END;

    IF @nik IS NULL
    BEGIN
        SET @bitparam = (
            SELECT '4040000' AS responseCode, 'User not found' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END;

    SET @bitparam = (
        SELECT
             '2002500' AS responseCode
            ,'OK' AS responseMessage
            ,JSON_QUERY((
                SELECT @nik AS nik
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )) AS data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO
