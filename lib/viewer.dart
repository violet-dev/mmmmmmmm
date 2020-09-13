import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

int currentPage = 0;

class ViewerPageProvider {
  final bool useFileSystem;
  final bool useWeb;
  final List<String> uris;
  final Map<String, String> headers;
  final int id;

  ViewerPageProvider({
    this.useFileSystem = false,
    this.useWeb = false,
    @required this.uris,
    @required this.id,
    this.headers,
  });
}

enum _ViewAppBarAction {
  toggleViewer,
  toggleRightToLeft,
  toggleScrollVertical,
}

class VerticalImageViewer extends StatefulWidget {
  final ViewerPageProvider pageInfo;

  VerticalImageViewer(this.pageInfo);

  @override
  _VerticalImageViewerState createState() => _VerticalImageViewerState();
}

class _VerticalImageViewerState extends State<VerticalImageViewer>
    with SingleTickerProviderStateMixin {
  ViewerPageProvider _pageInfo;
  Timer _clearTimer;
  List<bool> _loaded;
  List<double> _cachedHeight;
  ScrollController _scroll = ScrollController();
  int _prevPage = 1;
  double _opacity = 0.0;
  bool _disableBottom = false;

  @override
  void initState() {
    super.initState();

    // _clearTimer = Timer.periodic(Duration(seconds: 1), (timer) {
    //   imageCache.clearLiveImages();
    //   imageCache.clear();
    // });

    _scroll.addListener(() async {
      currentPage = offset2Page(_scroll.offset);
      if (_prevPage != currentPage) {
        if (currentPage > 0) {
          setState(() {
            _prevPage = currentPage;
          });
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pageInfo = widget.pageInfo;
    _loaded = List<bool>.filled(_pageInfo.uris.length, false);
    _cachedHeight = List<double>.filled(_pageInfo.uris.length, -1);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _clearTimer.cancel();
    PaintingBinding.instance.imageCache.clear();
    SystemChrome.setEnabledSystemUIOverlays([
      SystemUiOverlay.top,
      SystemUiOverlay.bottom,
    ]);
    imageCache.clearLiveImages();
    imageCache.clear();
    super.dispose();
  }

  int offset2Page(double offset) {
    double xx = -96;
    for (int i = 0; i < _cachedHeight.length; i++) {
      xx += _loaded[i] ? _cachedHeight[i] : 300;
      // xx += 4;
      if (offset < xx) {
        return i + 1;
      }
    }
    return _cachedHeight.length;
  }

  double page2Offset(int page) {
    double xx = 0.0;
    for (int i = 0; i < page; i++) {
      xx += _loaded[i] ? _cachedHeight[i] : 300;
    }
    return xx;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      sized: false,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        resizeToAvoidBottomPadding: false,
        appBar: _opacity == 1.0 ? _appBar() : null,
        body: _bodyVertical(),
      ),
    );
  }

  _appBar() {
    return AppBar(
      elevation: 0.0,
      backgroundColor: Colors.black.withOpacity(0.3),
      title: Text('$_prevPage/${_pageInfo.uris.length}'),
      leading: IconButton(
        icon: new Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.pop(context, currentPage);
          return new Future(() => false);
        },
      ),
      actions: [
        PopupMenuButton<_ViewAppBarAction>(
          onSelected: (action) {
            switch (action) {
              case _ViewAppBarAction.toggleViewer:
                break;

              case _ViewAppBarAction.toggleRightToLeft:
                break;

              case _ViewAppBarAction.toggleScrollVertical:
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _ViewAppBarAction.toggleViewer,
              child: Text('Toggle Viewer Style'),
            ),
            PopupMenuItem(
              value: _ViewAppBarAction.toggleRightToLeft,
              child: Text('Toggle Right To Left'),
            ),
            PopupMenuItem(
              value: _ViewAppBarAction.toggleScrollVertical,
              child: Text('Toggle Scroll Vertical'),
            ),
          ],
        ),
      ],
    );
  }

  _bodyVertical() {
    final height = MediaQuery.of(context).size.height;

    return Stack(
      children: <Widget>[
        Container(
          color: const Color(0xff444444),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _pageInfo.uris.length,
            controller: _scroll,
            cacheExtent: height * 2,
            itemBuilder: (context, index) {
              return _networkImageItem(index);
            },
          ),
        ),
        _touchArea(),
        !_disableBottom ? _bottomAppBar() : Container(),
      ],
    );
  }

  bool _overlayOpend = false;
  _touchArea() {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Align(
      alignment: Alignment.center,
      child: Container(
        color: null,
        width: width / 3,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () async {
            if (!_overlayOpend) {
              _prevPage = currentPage;
              setState(() {
                _opacity = 1.0;
                _disableBottom = false;
              });
              SystemChrome.setEnabledSystemUIOverlays(
                  [SystemUiOverlay.bottom, SystemUiOverlay.top]);
            } else {
              setState(() {
                _opacity = 0.0;
              });
              SystemChrome.setEnabledSystemUIOverlays([]);
              Future.delayed(Duration(milliseconds: 300)).then((value) {
                setState(() {
                  _disableBottom = true;
                });
              });
            }
            _overlayOpend = !_overlayOpend;
          },
        ),
      ),
    );
  }

  _networkImageItem(index) {
    final width = MediaQuery.of(context).size.width;
    return FutureBuilder(
      future: _calculateImageDimension(_pageInfo.uris[index]),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _loaded[index] = true;
          _cachedHeight[index] = width / snapshot.data.aspectRatio;
        }
        return Image.network(
          _pageInfo.uris[index],
          headers: _pageInfo.headers,
          fit: BoxFit.cover,
          width: 100,
          loadingBuilder: (context, string, progress) {
            return SizedBox(
              height: 300,
              child: Center(
                child: SizedBox(
                  child: CircularProgressIndicator(
                    value: progress != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes
                        : 0,
                  ),
                  width: 30,
                  height: 30,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Size> _calculateImageDimension(String url) async {
    Completer<Size> completer = Completer();
    Image image = Image.network(
      url,
      headers: _pageInfo.headers,
    );
    image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          var myImage = image.image;
          Size size = Size(myImage.width.toDouble(), myImage.height.toDouble());
          if (!completer.isCompleted) completer.complete(size);
        },
      ),
    );
    return completer.future;
  }

  _bottomAppBar() {
    final height = MediaQuery.of(context).size.height;
    final mediaQuery = MediaQuery.of(context);
    return AnimatedOpacity(
      opacity: _opacity,
      duration: Duration(milliseconds: 300),
      child: Padding(
        padding: EdgeInsets.only(
            top: height -
                (mediaQuery.padding + mediaQuery.viewInsets).bottom -
                (48)),
        child: Container(
          alignment: Alignment.bottomCenter,
          // padding: EdgeInsets.only(top: height - bottom - 48),
          color: Colors.black.withOpacity(0.2),
          height: 48,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Slider(
                value: _prevPage.toDouble() > 0 ? _prevPage.toDouble() : 1,
                max: _pageInfo.uris.length.toDouble(),
                min: 1,
                label: _prevPage.toString(),
                divisions: _pageInfo.uris.length,
                onChanged: (value) {
                  _scroll.jumpTo(page2Offset(_prevPage - 1) - 96);
                  currentPage = value.toInt();
                  setState(() {
                    _prevPage = value.toInt();
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
