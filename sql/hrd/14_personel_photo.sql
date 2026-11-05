USE RBACESS;
GO
/*
  Personel photo for list/detail cards.
  Source column: POS_SERVER.dbo.WEB_USER_MAIN.FOTO (filename)
  Public URL:    https://web.amscorp.id:3060/ImageProfile/{FOTO}

  Deploy this after backing up SPs — or re-run 09_personel_list_and_info.sql
  which already includes the same photo SELECT + OUTER APPLY.
*/
PRINT 'Personel photo is included in 09_personel_list_and_info.sql — run that file on RBACESS.';
GO
