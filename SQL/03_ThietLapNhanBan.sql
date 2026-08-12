/*======================================================================
  BUOC 4 - THIET LAP MERGE REPLICATION (CAY DAN XUAT)
  Chay tren: CHI SERVER (publisher)
  Chay bang: sqlcmd -S localhost\SERVER -E -f 65001 -i 03_ThietLapNhanBan.sql
  ----------------------------------------------------------------------
  TRUOC KHI CHAY, SUA 2 BIEN @MayChu / @ThuMucSnapshot cho khop may ban.

  CAY DAN XUAT (bo loc cua Merge Replication) - phan tan thanh 3 manh:

     Manh 1 (SERVER1 = CS1) va Manh 2 (SERVER2 = CS2) - GIONG NHAU:
        COSO                       <- NGUYEN THUY, row filter MACS = 'CS1'
        |- KHOA                    KHOA.MACS = COSO.MACS
           |- LOP                  LOP.MAKH = KHOA.MAKH
              |- GIAOVIEN_DANGKY   GIAOVIEN_DANGKY.MALOP = LOP.MALOP
              |- SINHVIEN          SINHVIEN.MALOP = LOP.MALOP
                 |- BANGDIEM       BANGDIEM.MASV = SINHVIEN.MASV

     Manh 3 (SERVER3 = tra cuu) - PHAN MANH DOC:
        Chi LOP + SINHVIEN cua CA HAI co so, va chi giu cac cot can thiet.

  Bang KHONG loc (nhan ban toan bo): MONHOC, GIAOVIEN, BODE, Bode_Muon,
  PhieuThi, PhieuThi_CauHoi.  Bang ChiTiet_BaiThi la CUC BO tung server.
======================================================================*/

/*----------------------------------------------------------------------
  0. THAM SO - SUA CHO KHOP MAY BAN
----------------------------------------------------------------------*/
:setvar MayChu          "DESKTOP-O6C61JT\SERVER"
:setvar MayCS1          "DESKTOP-O6C61JT\SERVER1"
:setvar MayCS2          "DESKTOP-O6C61JT\SERVER2"
:setvar MayTraCuu       "DESKTOP-O6C61JT\SERVER3"
:setvar ThuMucSnapshot  "D:\LEARN\PITT\CSDLPT\ReplData"
GO

/*----------------------------------------------------------------------
  1. CAU HINH DISTRIBUTOR
     Dung DUONG DAN CUC BO cho thu muc snapshot: ca 4 instance nam tren
     cung mot may nen khong can tao SMB share. Neu dat duong dan UNC ma
     share bi xoa thi TOAN BO snapshot se that bai.
----------------------------------------------------------------------*/
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE is_distributor = 1)
BEGIN
    EXEC sp_adddistributor @distributor = N'$(MayChu)', @password = N'';
    EXEC sp_adddistributiondb @database = N'distribution', @security_mode = 1;
    PRINT N'  Da cau hinh distributor';
END
ELSE PRINT N'  Distributor da co - bo qua';
GO

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.MSdistpublishers WHERE name = N'$(MayChu)')
BEGIN
    EXEC sp_adddistpublisher
         @publisher = N'$(MayChu)', @distribution_db = N'distribution',
         @security_mode = 1, @working_directory = N'$(ThuMucSnapshot)';
    PRINT N'  Da dang ky publisher';
END
GO

/* Bat nhan ban cho CSDL */
EXEC sp_replicationdboption @dbname = N'TN_CSDLPT',
     @optname = N'merge publish', @value = N'true';
GO

/*----------------------------------------------------------------------
  2. PUBLICATION CHO CO SO 1 VA CO SO 2
----------------------------------------------------------------------*/
USE TN_CSDLPT;
GO

DECLARE @pub sysname, @macs nchar(3), @i int = 1;
WHILE @i <= 2
BEGIN
    SET @pub  = N'TN_CSDLPT_CS' + CAST(@i AS nvarchar(1));
    SET @macs = N'CS' + CAST(@i AS nvarchar(1));

    IF NOT EXISTS (SELECT 1 FROM sysmergepublications WHERE name = @pub)
    BEGIN
        EXEC sp_addmergepublication
             @publication = @pub,
             @description = @macs,          /* hien trong ComboBox dang nhap */
             @publication_compatibility_level = N'90RTM',
             @allow_anonymous = N'false', @immediate_sync = N'false';

        EXEC sp_addpublication_snapshot @publication = @pub, @publisher_security_mode = 1;
        PRINT N'  Da tao publication ' + @pub;
    END

    /*--- Article: bang GOC co row filter ---*/
    IF NOT EXISTS (SELECT 1 FROM sysmergearticles a JOIN sysmergepublications p ON a.pubid=p.pubid
                   WHERE p.name=@pub AND a.name='COSO')
        EXEC sp_addmergearticle @publication=@pub, @article='COSO', @source_object='COSO',
             @subset_filterclause = N'[MACS] = ''' + @macs + N'''';

    /*--- Cac article con ---*/
    DECLARE @b sysname;
    DECLARE cb CURSOR FOR
        SELECT * FROM (VALUES ('KHOA'),('LOP'),('SINHVIEN'),('GIAOVIEN'),('GIAOVIEN_DANGKY'),
                              ('BANGDIEM'),('MONHOC'),('BODE'),('Bode_Muon'),
                              ('PhieuThi'),('PhieuThi_CauHoi')) v(t);
    OPEN cb; FETCH NEXT FROM cb INTO @b;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM sysmergearticles a JOIN sysmergepublications p ON a.pubid=p.pubid
                       WHERE p.name=@pub AND a.name=@b)
            EXEC sp_addmergearticle @publication=@pub, @article=@b, @source_object=@b;
        FETCH NEXT FROM cb INTO @b;
    END
    CLOSE cb; DEALLOCATE cb;

    /*--- CAY DAN XUAT: join filter theo khoa ngoai (CHA truoc, CON sau) ---*/
    IF NOT EXISTS (SELECT 1 FROM sysmergesubsetfilters sf JOIN sysmergepublications p ON sf.pubid=p.pubid
                   WHERE p.name=@pub AND sf.filtername='KHOA_COSO')
        EXEC sp_addmergefilter @publication=@pub, @article='KHOA', @join_articlename='COSO',
             @filtername='KHOA_COSO', @join_filterclause=N'[KHOA].[MACS] = [COSO].[MACS]',
             @join_unique_key=1;

    IF NOT EXISTS (SELECT 1 FROM sysmergesubsetfilters sf JOIN sysmergepublications p ON sf.pubid=p.pubid
                   WHERE p.name=@pub AND sf.filtername='LOP_KHOA')
        EXEC sp_addmergefilter @publication=@pub, @article='LOP', @join_articlename='KHOA',
             @filtername='LOP_KHOA', @join_filterclause=N'[LOP].[MAKH] = [KHOA].[MAKH]',
             @join_unique_key=1;

    IF NOT EXISTS (SELECT 1 FROM sysmergesubsetfilters sf JOIN sysmergepublications p ON sf.pubid=p.pubid
                   WHERE p.name=@pub AND sf.filtername='GIAOVIEN_DANGKY_LOP')
        EXEC sp_addmergefilter @publication=@pub, @article='GIAOVIEN_DANGKY', @join_articlename='LOP',
             @filtername='GIAOVIEN_DANGKY_LOP',
             @join_filterclause=N'[GIAOVIEN_DANGKY].[MALOP] = [LOP].[MALOP]', @join_unique_key=1;

    IF NOT EXISTS (SELECT 1 FROM sysmergesubsetfilters sf JOIN sysmergepublications p ON sf.pubid=p.pubid
                   WHERE p.name=@pub AND sf.filtername='SINHVIEN_LOP')
        EXEC sp_addmergefilter @publication=@pub, @article='SINHVIEN', @join_articlename='LOP',
             @filtername='SINHVIEN_LOP',
             @join_filterclause=N'[SINHVIEN].[MALOP] = [LOP].[MALOP]', @join_unique_key=1;

    IF NOT EXISTS (SELECT 1 FROM sysmergesubsetfilters sf JOIN sysmergepublications p ON sf.pubid=p.pubid
                   WHERE p.name=@pub AND sf.filtername='BANGDIEM_SINHVIEN')
        EXEC sp_addmergefilter @publication=@pub, @article='BANGDIEM', @join_articlename='SINHVIEN',
             @filtername='BANGDIEM_SINHVIEN',
             @join_filterclause=N'[BANGDIEM].[MASV] = [SINHVIEN].[MASV]', @join_unique_key=1;

    PRINT N'  Da dung cay dan xuat cho ' + @pub;
    SET @i += 1;
END
GO

/*----------------------------------------------------------------------
  3. PUBLICATION TRA CUU (MANH DOC)
     Chi 2 bang, KHONG loc dong (lay ca hai co so), chi CAT COT.
----------------------------------------------------------------------*/
IF NOT EXISTS (SELECT 1 FROM sysmergepublications WHERE name = N'TN_CSDLPT_TRACUU')
BEGIN
    EXEC sp_addmergepublication
         @publication = N'TN_CSDLPT_TRACUU', @description = N'Tra cuu',
         @publication_compatibility_level = N'90RTM',
         @allow_anonymous = N'false', @immediate_sync = N'false';
    EXEC sp_addpublication_snapshot @publication = N'TN_CSDLPT_TRACUU', @publisher_security_mode = 1;

    EXEC sp_addmergearticle @publication=N'TN_CSDLPT_TRACUU', @article='LOP',      @source_object='LOP';
    EXEC sp_addmergearticle @publication=N'TN_CSDLPT_TRACUU', @article='SINHVIEN', @source_object='SINHVIEN';
    PRINT N'  Da tao publication tra cuu';
END
GO

/*--- PHAN MANH DOC: bo cac cot khong can cho viec tra cuu ---
  SINHVIEN: bo NGAYSINH, DIACHI, PASSWORD  -> chi con MASV, HO, TEN, MALOP
  LOP     : bo MAKH                        -> chi con MALOP, TENLOP
  Cot PASSWORD phai co DEFAULT thi moi cat duoc (SQL Server bat buoc). */
DECLARE @cot sysname;
DECLARE cc CURSOR FOR SELECT * FROM (VALUES ('NGAYSINH'),('DIACHI'),('PASSWORD')) v(c);
OPEN cc; FETCH NEXT FROM cc INTO @cot;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC sp_mergearticlecolumn @publication=N'TN_CSDLPT_TRACUU', @article='SINHVIEN',
             @column=@cot, @operation='drop', @force_invalidate_snapshot=1;
    END TRY BEGIN CATCH PRINT N'  (bo qua cot ' + @cot + N': ' + ERROR_MESSAGE() + N')'; END CATCH
    FETCH NEXT FROM cc INTO @cot;
END
CLOSE cc; DEALLOCATE cc;

BEGIN TRY
    EXEC sp_mergearticlecolumn @publication=N'TN_CSDLPT_TRACUU', @article='LOP',
         @column='MAKH', @operation='drop', @force_invalidate_snapshot=1;
END TRY BEGIN CATCH PRINT N'  (bo qua cot MAKH: ' + ERROR_MESSAGE() + N')'; END CATCH
PRINT N'  Da cat cot cho manh doc';
GO

/*----------------------------------------------------------------------
  4. SUBSCRIPTION (push)
     LUU Y QUAN TRONG: dung SQL auth (@subscriber_security_mode = 0).
     Neu de Windows auth thi agent chay bang tai khoan dich vu SQL Agent
     cua publisher - tai khoan nay thuong KHONG co login tren subscriber
     -> loi "The process could not connect to Subscriber".
----------------------------------------------------------------------*/
DECLARE @dsSub TABLE (pub sysname, sub sysname);
INSERT INTO @dsSub VALUES
    (N'TN_CSDLPT_CS1',    N'$(MayCS1)'),
    (N'TN_CSDLPT_CS2',    N'$(MayCS2)'),
    (N'TN_CSDLPT_TRACUU', N'$(MayTraCuu)');

DECLARE @p sysname, @s sysname;
DECLARE cs CURSOR FOR SELECT pub, sub FROM @dsSub;
OPEN cs; FETCH NEXT FROM cs INTO @p, @s;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sysmergesubscriptions ms
                   JOIN sysmergepublications mp ON ms.pubid = mp.pubid
                   WHERE mp.name = @p AND ms.subscriber_server = @s)
    BEGIN
        EXEC sp_addmergesubscription
             @publication=@p, @subscriber=@s, @subscriber_db=N'TN_CSDLPT',
             @subscription_type=N'push', @sync_type=N'automatic', @subscriber_type=N'local';

        EXEC sp_addmergepushsubscription_agent
             @publication=@p, @subscriber=@s, @subscriber_db=N'TN_CSDLPT',
             @subscriber_security_mode=0, @subscriber_login=N'sa',
             @publisher_security_mode=1, @frequency_type=64;

        PRINT N'  Da tao subscription ' + @p + N' -> ' + @s;
    END
    FETCH NEXT FROM cs INTO @p, @s;
END
CLOSE cs; DEALLOCATE cs;
GO

/*----------------------------------------------------------------------
  5. TAO SNAPSHOT BAN DAU
----------------------------------------------------------------------*/
EXEC sp_startpublication_snapshot @publication = N'TN_CSDLPT_CS1';
EXEC sp_startpublication_snapshot @publication = N'TN_CSDLPT_CS2';
EXEC sp_startpublication_snapshot @publication = N'TN_CSDLPT_TRACUU';
GO

PRINT N'';
PRINT N'== Da thiet lap xong nhan ban ==';
PRINT N'Cho snapshot chay xong (theo doi trong Replication Monitor),';
PRINT N'sau do khoi dong Merge Agent de du lieu lan xuong cac phan manh.';
GO

/*----------------------------------------------------------------------
  6. KIEM TRA CAY DAN XUAT
----------------------------------------------------------------------*/
SELECT publication = p.name,
       con = ch.name, cha = pa.name,
       dieu_kien = CAST(sf.join_filterclause AS nvarchar(80))
FROM sysmergesubsetfilters sf
JOIN sysmergepublications p ON sf.pubid = p.pubid
JOIN sysmergearticles ch ON sf.art_nickname  = ch.nickname AND ch.pubid = sf.pubid
JOIN sysmergearticles pa ON sf.join_nickname = pa.nickname AND pa.pubid = sf.pubid
ORDER BY p.name, pa.name, ch.name;
GO
