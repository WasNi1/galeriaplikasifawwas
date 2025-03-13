import 'package:aplikasi_galeri_baru/widget/dialog_foto.dart';
import 'package:aplikasi_galeri_baru/widget/grid_foto_view.dart';
import 'package:flutter/material.dart';

class FotoPages extends StatefulWidget {
  const FotoPages ({super.key});

  @override
  State<FotoPages> createState() => _FotoPagesState();
}

class _FotoPagesState extends State<FotoPages> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;


  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const FotoGroupedGridView();
  }
}