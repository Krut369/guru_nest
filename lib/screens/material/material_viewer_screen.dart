import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_protector/screen_protector.dart';

class MaterialViewerScreen extends StatefulWidget {
  final String url;
  final String type;
  final String title;

  const MaterialViewerScreen({
    Key? key,
    required this.url,
    required this.type,
    required this.title,
  }) : super(key: key);

  @override
  State<MaterialViewerScreen> createState() => _MaterialViewerScreenState();
}

class _MaterialViewerScreenState extends State<MaterialViewerScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _error;
  String? _localPath;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('Initializing MaterialViewerScreen with URL: ${widget.url}');
    print('Material type: ${widget.type}');
    _loadMaterial();
    _protectScreen();
  }
  Future<void> _protectScreen() async {
    await ScreenProtector.preventScreenshotOn();
    }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _videoPlayerController?.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_videoPlayerController?.value.isPlaying ?? false) {
        _videoPlayerController?.play();
      }
    }
  }

  Future<void> _loadMaterial() async {
    if (_isDisposed) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      if (widget.type == 'pdf') {
        await _loadPdf();
      } else if (widget.type == 'video') {
        await _loadVideo();
      } else {
        final uri = Uri.parse(widget.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!_isDisposed) {
            Navigator.pop(context);
          }
        } else {
          throw Exception('Could not open file in external viewer');
        }
      }

      if (!_isDisposed) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading material: $e');
      if (!_isDisposed) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPdf() async {
    try {
      print('Starting PDF download from: ${widget.url}');

      // For web platforms, open PDF in browser
      if (kIsWeb) {
        final uri = Uri.parse(widget.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!_isDisposed) {
            Navigator.pop(context);
          }
        } else {
          throw Exception('Could not open PDF in browser');
        }
        return;
      }

      final dio = Dio();

      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('Could not access external storage');
      }

      final fileName = widget.url.split('/').last;
      _localPath = '${directory.path}/$fileName';
      print('PDF will be saved to: $_localPath');

      final file = File(_localPath!);
      if (await file.exists()) {
        print('PDF file already exists, using cached version');
        return;
      }

      await dio.download(
        widget.url,
        _localPath!,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            print('Download progress: $progress%');
          }
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) {
            return status! < 500;
          },
          headers: {
            'Accept': '*/*',
            'User-Agent': 'Mozilla/5.0',
          },
        ),
      );

      if (!await file.exists()) {
        throw Exception('File download completed but file not found');
      }

      print('PDF download completed successfully');
    } catch (e) {
      print('Error downloading PDF: $e');
      throw Exception('Failed to download PDF: $e');
    }
  }

  Future<void> _loadVideo() async {
    try {
      print('Initializing video player with URL: ${widget.url}');

      // Dispose existing controllers if any
      await _videoPlayerController?.dispose();
      _chewieController?.dispose();

      _videoPlayerController = VideoPlayerController.network(
        widget.url,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
        httpHeaders: {
          'Accept': '*/*',
          'User-Agent': 'Mozilla/5.0',
        },
      );

      await _videoPlayerController!.initialize();
      print('Video player initialized successfully');

      if (_isDisposed) {
        await _videoPlayerController?.dispose();
        return;
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          print('Video player error: $errorMessage');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error: $errorMessage',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadMaterial,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        },
      );
      print('Chewie controller initialized successfully');
    } catch (e) {
      print('Error initializing video player: $e');
      throw Exception('Failed to initialize video player: $e');
    }
  }

  @override
  void dispose() {
    print('Disposing MaterialViewerScreen');
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _videoPlayerController?.pause();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _videoPlayerController?.pause();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading material...'),
                  ],
                ),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading material: $_error',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadMaterial,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : widget.type == 'pdf' && !kIsWeb
                    ? PDFView(
                        filePath: _localPath!,
                        enableSwipe: true,
                        swipeHorizontal: false,
                        autoSpacing: true,
                        pageFling: true,
                        pageSnap: true,
                        fitPolicy: FitPolicy.BOTH,
                        preventLinkNavigation: false,
                        onError: (error) {
                          print('PDF viewer error: $error');
                          if (!_isDisposed) {
                            setState(() {
                              _error = error.toString();
                            });
                          }
                        },
                        onPageError: (page, error) {
                          print('PDF page error: $error');
                          if (!_isDisposed) {
                            setState(() {
                              _error = 'Error loading page $page: $error';
                            });
                          }
                        },
                      )
                    : Chewie(controller: _chewieController!),
      ),
    );
  }
}
