/* Patch lookup: overtime_level / overtime_jabatan (ASP overtime_amount_lookup) */
USE RBACESS;
GO
/* Applied live via ALTER on xsp_ams_new_hrd_lookup_getrows.
   Types:
   - overtime_level / ot_level  → PangkatStr (+ NON STAFF), value=label
   - overtime_jabatan / ot_jabatan → KodeJabatanStr (+ ALL), label=JabatanStr
   Re-run agent deploy if Unknown lookup type appears for these keys.
*/
GO
