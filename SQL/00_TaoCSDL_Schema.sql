/*======================================================================
  BUOC 1 - TAO CO SO DU LIEU VA CAU TRUC BANG
  Chay tren: CA 4 SERVER (SERVER, SERVER1, SERVER2, SERVER3)
  Chay bang: sqlcmd -S localhost\SERVER -E -f 65001 -i 00_TaoCSDL_Schema.sql
  ----------------------------------------------------------------------
  LUU Y: script KHONG tao cot rowguid. Cot nay do Merge Replication tu
  them vao khi ta cau hinh nhan ban o buoc 4.
======================================================================*/
IF DB_ID('TN_CSDLPT') IS NULL
BEGIN
    CREATE DATABASE TN_CSDLPT;
    PRINT N'Da tao CSDL TN_CSDLPT';
END
ELSE PRINT N'CSDL TN_CSDLPT da ton tai - bo qua buoc tao';
GO

USE TN_CSDLPT;
GO

/*----- XOA BANG CU (neu chay lai) - xoa CON truoc CHA -----*/
IF OBJECT_ID('dbo.ChiTiet_BaiThi')  IS NOT NULL DROP TABLE dbo.ChiTiet_BaiThi;
IF OBJECT_ID('dbo.PhieuThi_CauHoi') IS NOT NULL DROP TABLE dbo.PhieuThi_CauHoi;
IF OBJECT_ID('dbo.PhieuThi')        IS NOT NULL DROP TABLE dbo.PhieuThi;
IF OBJECT_ID('dbo.BANGDIEM')        IS NOT NULL DROP TABLE dbo.BANGDIEM;
IF OBJECT_ID('dbo.GIAOVIEN_DANGKY') IS NOT NULL DROP TABLE dbo.GIAOVIEN_DANGKY;
IF OBJECT_ID('dbo.Bode_Muon')       IS NOT NULL DROP TABLE dbo.Bode_Muon;
IF OBJECT_ID('dbo.BODE')            IS NOT NULL DROP TABLE dbo.BODE;
IF OBJECT_ID('dbo.SINHVIEN')        IS NOT NULL DROP TABLE dbo.SINHVIEN;
IF OBJECT_ID('dbo.GIAOVIEN')        IS NOT NULL DROP TABLE dbo.GIAOVIEN;
IF OBJECT_ID('dbo.MONHOC')          IS NOT NULL DROP TABLE dbo.MONHOC;
IF OBJECT_ID('dbo.LOP')             IS NOT NULL DROP TABLE dbo.LOP;
IF OBJECT_ID('dbo.KHOA')            IS NOT NULL DROP TABLE dbo.KHOA;
IF OBJECT_ID('dbo.COSO')            IS NOT NULL DROP TABLE dbo.COSO;
GO

/*----- CAU TRUC BANG -----*/
CREATE TABLE dbo.[COSO](
    [MACS] nchar(3) NOT NULL,
    [TENCS] nvarchar(50) NOT NULL,
    [DIACHI] nvarchar(100) NULL,
    CONSTRAINT [PK_COSO] PRIMARY KEY CLUSTERED ([MACS])
);
GO

CREATE TABLE dbo.[KHOA](
    [MAKH] nchar(8) NOT NULL,
    [TENKH] nvarchar(50) NOT NULL,
    [MACS] nchar(3) NOT NULL,
    CONSTRAINT [PK_KHOA] PRIMARY KEY CLUSTERED ([MAKH])
);
GO

CREATE TABLE dbo.[LOP](
    [MALOP] nchar(15) NOT NULL,
    [TENLOP] nvarchar(50) NOT NULL,
    [MAKH] nchar(8) NULL,
    CONSTRAINT [PK_LOP] PRIMARY KEY CLUSTERED ([MALOP])
);
GO

CREATE TABLE dbo.[MONHOC](
    [MAMH] char(5) NOT NULL,
    [TENMH] nvarchar(50) NULL,
    CONSTRAINT [PK_MONHOC] PRIMARY KEY CLUSTERED ([MAMH])
);
GO

CREATE TABLE dbo.[GIAOVIEN](
    [MAGV] char(8) NOT NULL,
    [HO] nvarchar(50) NULL,
    [TEN] nvarchar(10) NULL,
    [MAKH] nchar(8) NULL,
    [HOCVI] nvarchar(40) NULL,
    CONSTRAINT [PK_GIAOVIEN] PRIMARY KEY CLUSTERED ([MAGV])
);
GO

CREATE TABLE dbo.[SINHVIEN](
    [MASV] char(8) NOT NULL,
    [HO] nvarchar(50) NULL,
    [TEN] nvarchar(10) NULL,
    [NGAYSINH] date NULL,
    [DIACHI] nvarchar(100) NULL,
    [MALOP] nchar(15) NULL,
    [PASSWORD] nvarchar(30) NOT NULL CONSTRAINT [DF_SINHVIEN_PASSWORD] DEFAULT (N''),
    CONSTRAINT [PK_SINHVIEN] PRIMARY KEY CLUSTERED ([MASV])
);
GO

CREATE TABLE dbo.[BODE](
    [CAUHOI] int NOT NULL,
    [MAMH] char(5) NULL,
    [TRINHDO] char(1) NULL,
    [NOIDUNG] ntext NULL,
    [A] ntext NULL,
    [B] ntext NULL,
    [C] ntext NULL,
    [D] ntext NULL,
    [DAP_AN] char(1) NULL,
    [MAGV] char(8) NULL,
    CONSTRAINT [PK_BODE] PRIMARY KEY CLUSTERED ([CAUHOI])
);
GO

CREATE TABLE dbo.[Bode_Muon](
    [CAUHOI] int NOT NULL,
    [MACS] nchar(3) NOT NULL,
    [MAMH] char(5) NOT NULL,
    [TRINHDO] char(1) NOT NULL,
    [NOIDUNG] nvarchar(max) NULL,
    [A] nvarchar(max) NULL,
    [B] nvarchar(max) NULL,
    [C] nvarchar(max) NULL,
    [D] nvarchar(max) NULL,
    [DAP_AN] char(1) NOT NULL,
    [MAGV] char(8) NOT NULL,
    CONSTRAINT [PK_Bode_Muon] PRIMARY KEY CLUSTERED ([CAUHOI])
);
GO

CREATE TABLE dbo.[GIAOVIEN_DANGKY](
    [MAGV] char(8) NULL,
    [MAMH] char(5) NOT NULL,
    [MALOP] nchar(15) NOT NULL,
    [TRINHDO] char(1) NULL,
    [NGAYTHI] datetime NOT NULL CONSTRAINT [DF_GIAOVIEN_DANGKY_NGAYTHI] DEFAULT (getdate()),
    [LAN] smallint NOT NULL,
    [SOCAUTHI] smallint NULL,
    [THOIGIAN] smallint NULL,
    CONSTRAINT [PK_GIAOVIEN_DANGKY] PRIMARY KEY CLUSTERED ([MAMH], [MALOP], [LAN])
);
GO

CREATE TABLE dbo.[BANGDIEM](
    [MASV] char(8) NOT NULL,
    [MAMH] char(5) NOT NULL,
    [LAN] smallint NOT NULL,
    [NGAYTHI] datetime NULL,
    [DIEM] float NULL,
    CONSTRAINT [PK_BANGDIEM] PRIMARY KEY CLUSTERED ([MASV], [MAMH], [LAN])
);
GO

CREATE TABLE dbo.[PhieuThi](
    [MAPHIEU] uniqueidentifier NOT NULL CONSTRAINT [DF_PhieuThi_MAPHIEU] DEFAULT (newid()),
    [MASV] char(8) NOT NULL,
    [MAMH] char(5) NOT NULL,
    [LAN] smallint NOT NULL,
    [MALOP] nchar(15) NOT NULL,
    [TRINHDO] char(1) NOT NULL,
    [SOCAU] smallint NOT NULL,
    [THOIGIAN] smallint NOT NULL,
    [BATDAU] datetime NOT NULL CONSTRAINT [DF_PhieuThi_BATDAU] DEFAULT (getdate()),
    [HANNOP] datetime NOT NULL,
    [DANOP] bit NOT NULL CONSTRAINT [DF_PhieuThi_DANOP] DEFAULT ((0)),
    [THITHU] bit NOT NULL CONSTRAINT [DF_PhieuThi_THITHU] DEFAULT ((0)),
    CONSTRAINT [PK_PhieuThi] PRIMARY KEY CLUSTERED ([MAPHIEU])
);
GO

CREATE TABLE dbo.[PhieuThi_CauHoi](
    [MAPHIEU] uniqueidentifier NOT NULL,
    [STT] int NOT NULL,
    [CAUHOI] int NOT NULL,
    [NGUON] varchar(5) NOT NULL,
    [NOIDUNG] nvarchar(max) NULL,
    [A] nvarchar(max) NULL,
    [B] nvarchar(max) NULL,
    [C] nvarchar(max) NULL,
    [D] nvarchar(max) NULL,
    [DAP_AN] char(1) NOT NULL,
    CONSTRAINT [PK_PhieuThi_CauHoi] PRIMARY KEY CLUSTERED ([MAPHIEU], [STT])
);
GO

CREATE TABLE dbo.[ChiTiet_BaiThi](
    [MASV] char(
8) NOT NULL,
    [MAMH] char(5) NOT NULL,
    [LAN] smallint NOT NULL,
    [STT] int NOT NULL,
    [CAUHOI] int NOT NULL,
    [NOIDUNG] nvarchar(max) NULL,
    [A] nvarchar(max) NULL,
    [B] nvarchar(max) NULL,
    [C] nvarchar(max) NULL,
    [D] nvarchar(max) NULL,
    [DAP_AN] char(1) NULL,
    [DACHON] char(1) NULL,
    CONSTRAINT [PK_ChiTiet_BaiThi] PRIMARY KEY CLUSTERED ([MASV], [MAMH], [LAN], [CAUHOI])
);
GO

/*----- KHOA NGOAI -----*/
ALTER TABLE dbo.[BANGDIEM] ADD CONSTRAINT [FK_BANGDIEM_MONHOC] FOREIGN KEY ([MAMH]) REFERENCES dbo.[MONHOC] ([MAMH]);
ALTER TABLE dbo.[BANGDIEM] ADD CONSTRAINT [FK_BANGDIEM_SINHVIEN1] FOREIGN KEY ([MASV]) REFERENCES dbo.[SINHVIEN] ([MASV]);
ALTER TABLE dbo.[BODE] ADD CONSTRAINT [FK_BODE_GIAOVIEN] FOREIGN KEY ([MAGV]) REFERENCES dbo.[GIAOVIEN] ([MAGV]);
ALTER TABLE dbo.[BODE] ADD CONSTRAINT [FK_BODE_MONHOC] FOREIGN KEY ([MAMH]) REFERENCES dbo.[MONHOC] ([MAMH]);
ALTER TABLE dbo.[GIAOVIEN] ADD CONSTRAINT [FK_GIAOVIEN_KHOA] FOREIGN KEY ([MAKH]) REFERENCES dbo.[KHOA] ([MAKH]);
ALTER TABLE dbo.[GIAOVIEN_DANGKY] ADD CONSTRAINT [FK_GIAOVIEN_DANGKY_GIAOVIEN1] FOREIGN KEY ([MAGV]) REFERENCES dbo.[GIAOVIEN] ([MAGV]);
ALTER TABLE dbo.[GIAOVIEN_DANGKY] ADD CONSTRAINT [FK_GIAOVIEN_DANGKY_LOP] FOREIGN KEY ([MALOP]) REFERENCES dbo.[LOP] ([MALOP]);
ALTER TABLE dbo.[GIAOVIEN_DANGKY] ADD CONSTRAINT [FK_GIAOVIEN_DANGKY_MONHOC1] FOREIGN KEY ([MAMH]) REFERENCES dbo.[MONHOC] ([MAMH]);
ALTER TABLE dbo.[KHOA] ADD CONSTRAINT [FK_KHOA_COSO] FOREIGN KEY ([MACS]) REFERENCES dbo.[COSO] ([MACS]);
ALTER TABLE dbo.[LOP] ADD CONSTRAINT [FK_LOP_KHOA] FOREIGN KEY ([MAKH]) REFERENCES dbo.[KHOA] ([MAKH]);
ALTER TABLE dbo.[SINHVIEN] ADD CONSTRAINT [FK_SINHVIEN_LOP] FOREIGN KEY ([MALOP]) REFERENCES dbo.[LOP] ([MALOP]);
ALTER TABLE dbo.[PhieuThi_CauHoi] ADD CONSTRAINT [FK_PTCH_Phieu] FOREIGN KEY ([MAPHIEU]) REFERENCES dbo.[PhieuThi] ([MAPHIEU]);
GO


PRINT N'== Da tao xong cau truc bang ==';
GO
