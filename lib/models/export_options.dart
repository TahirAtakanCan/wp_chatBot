enum ExportColumn {
  sira,
  isim,
  telefon,
  sablon,
  durum,
  hataKodu,
  hataKategori,
  hataDetay,
  gonderimTarihi,
  iletildiTarihi,
  okunduTarihi,
  basarisizTarihi;

  String get label {
    switch (this) {
      case ExportColumn.sira:
        return 'Sıra';
      case ExportColumn.isim:
        return 'İsim';
      case ExportColumn.telefon:
        return 'Telefon';
      case ExportColumn.sablon:
        return 'Şablon';
      case ExportColumn.durum:
        return 'Durum';
      case ExportColumn.hataKodu:
        return 'Hata Kodu';
      case ExportColumn.hataKategori:
        return 'Hata Kategorisi';
      case ExportColumn.hataDetay:
        return 'Hata Detayı';
      case ExportColumn.gonderimTarihi:
        return 'Gönderim';
      case ExportColumn.iletildiTarihi:
        return 'İletildi';
      case ExportColumn.okunduTarihi:
        return 'Okundu';
      case ExportColumn.basarisizTarihi:
        return 'Başarısız';
    }
  }

  String get apiName {
    switch (this) {
      case ExportColumn.sira:
        return 'SIRA';
      case ExportColumn.isim:
        return 'ISIM';
      case ExportColumn.telefon:
        return 'TELEFON';
      case ExportColumn.sablon:
        return 'SABLON';
      case ExportColumn.durum:
        return 'DURUM';
      case ExportColumn.hataKodu:
        return 'HATA_KODU';
      case ExportColumn.hataKategori:
        return 'HATA_KATEGORI';
      case ExportColumn.hataDetay:
        return 'HATA_DETAY';
      case ExportColumn.gonderimTarihi:
        return 'GONDERIM_TARIHI';
      case ExportColumn.iletildiTarihi:
        return 'ILETILDI_TARIHI';
      case ExportColumn.okunduTarihi:
        return 'OKUNDU_TARIHI';
      case ExportColumn.basarisizTarihi:
        return 'BASARISIZ_TARIHI';
    }
  }
}

class ExportOptions {
  String? status;
  int? days;
  List<String> failureCodes;
  String? templateName;
  String? phoneSearch;
  String? contactNameSearch;
  Set<ExportColumn> columns;
  String? sortBy;

  ExportOptions({
    this.status,
    this.days,
    this.failureCodes = const [],
    this.templateName,
    this.phoneSearch,
    this.contactNameSearch,
    this.columns = const {},
    this.sortBy,
  });

  Map<String, dynamic> toJson() {
    return {
      if (status != null) 'status': status,
      if (days != null) 'days': days,
      if (failureCodes.isNotEmpty) 'failureCodes': failureCodes,
      if (templateName != null) 'templateName': templateName,
      if (phoneSearch != null && phoneSearch!.isNotEmpty)
        'phoneSearch': phoneSearch,
      if (contactNameSearch != null && contactNameSearch!.isNotEmpty)
        'contactNameSearch': contactNameSearch,
      if (columns.isNotEmpty) 'columns': columns.map((c) => c.apiName).toList(),
      if (sortBy != null) 'sortBy': sortBy,
    };
  }
}
