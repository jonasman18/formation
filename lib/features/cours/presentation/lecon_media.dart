import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../shared/utils/errors.dart';

/// Transforme un chemin Storage en lien temporaire (1 h) ; laisse passer les liens http.
Future<String> _urlSignee(WidgetRef ref, String chemin) async {
  if (chemin.startsWith('http')) return chemin;
  return ref
      .read(supabaseClientProvider)
      .storage
      .from('documents')
      .createSignedUrl(chemin, 3600);
}

class PdfLecon extends ConsumerStatefulWidget {
  const PdfLecon({super.key, required this.chemin});
  final String? chemin;

  @override
  ConsumerState<PdfLecon> createState() => _PdfLeconState();
}

class _PdfLeconState extends ConsumerState<PdfLecon> {
  bool _busy = false;

  Future<void> _ouvrir() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final url = await _urlSignee(ref, widget.chemin!);
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le document.')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chemin == null || widget.chemin!.isEmpty) {
      return const Text('Aucun document pour cette leçon.');
    }
    return Center(
      child: FilledButton.icon(
        onPressed: _busy ? null : _ouvrir,
        icon: _busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.picture_as_pdf),
        label: const Text('Ouvrir le document PDF'),
      ),
    );
  }
}

class VideoLecon extends ConsumerStatefulWidget {
  const VideoLecon({super.key, required this.chemin});
  final String? chemin;

  @override
  ConsumerState<VideoLecon> createState() => _VideoLeconState();
}

class _VideoLeconState extends ConsumerState<VideoLecon> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  String? _erreur;
  bool _chargement = true;

  bool get _estLien => (widget.chemin ?? '').startsWith('http');

  @override
  void initState() {
    super.initState();
    if (widget.chemin == null || widget.chemin!.isEmpty) {
      _chargement = false;
      _erreur = 'Aucune vidéo pour cette leçon.';
    } else if (_estLien) {
      _chargement = false; // ancien lien externe : bouton « Ouvrir »
    } else {
      _charger();
    }
  }

  Future<void> _charger() async {
    try {
      final url = await _urlSignee(ref, widget.chemin!);
      final video = VideoPlayerController.networkUrl(Uri.parse(url));
      await video.initialize();
      if (!mounted) {
        await video.dispose();
        return;
      }
      setState(() {
        _video = video;
        _chewie = ChewieController(
          videoPlayerController: video,
          aspectRatio: video.value.aspectRatio,
        );
        _chargement = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _erreur = 'Lecture impossible : ${humanError(e)}';
          _chargement = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_erreur != null) return Text(_erreur!);
    if (_estLien) {
      return Center(
        child: FilledButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(widget.chemin!),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Ouvrir la vidéo'),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: _video!.value.aspectRatio,
      child: Chewie(controller: _chewie!),
    );
  }
}