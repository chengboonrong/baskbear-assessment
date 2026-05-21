import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Central registry of the hand-authored Lottie assets in `assets/lottie/`.
/// Every path here is parse-validated by `test/shared/lottie_assets_test.dart`.
class AppLottie {
  const AppLottie._();
  static const loading = 'assets/lottie/coffee_loading.json';
  static const coffeeCup = 'assets/lottie/coffee_cup.json';
  static const bear = 'assets/lottie/bear_avatar.json';
  static const empty = 'assets/lottie/empty_state.json';
  static const footerSteam = 'assets/lottie/footer_steam.json';

  // Bottom-nav tab icons (monochrome line/solid glyphs, recoloured at runtime).
  static const tabMenu = 'assets/lottie/tab_menu.json';
  static const tabCart = 'assets/lottie/tab_cart.json';
  static const tabOrders = 'assets/lottie/tab_orders.json';
  static const tabOffers = 'assets/lottie/tab_offers.json';
  static const tabBarista = 'assets/lottie/tab_barista.json';
  static const tabAccount = 'assets/lottie/tab_account.json';
}

/// Brewing-coffee spinner — the app-wide replacement for
/// [CircularProgressIndicator] on async screens and in buttons.
class LottieLoader extends StatelessWidget {
  const LottieLoader({super.key, this.size = 96, this.center = true});

  final double size;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final anim = Lottie.asset(AppLottie.loading, width: size, height: size);
    return center ? Center(child: anim) : anim;
  }
}

/// Circular "Baskbear" mascot avatar — used wherever a person/brand avatar
/// appears (account, AI barista recommendations).
class BearAvatar extends StatelessWidget {
  const BearAvatar({super.key, this.size = 48, this.background});

  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? Theme.of(context).colorScheme.primaryContainer;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(size * 0.04),
      child: Lottie.asset(AppLottie.bear, fit: BoxFit.contain),
    );
  }
}

/// Menu artwork: an animated coffee cup on the brand container. When the item
/// has an [imageUrl] the network image is shown, with the cup animation as the
/// loading/error placeholder so there's never a blank box.
class CoffeeThumb extends StatelessWidget {
  const CoffeeThumb({
    super.key,
    this.width = 64,
    this.height = 64,
    this.imageUrl,
    this.radius = 12,
  });

  final double width;
  final double height;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pad = math.min(width, height) * 0.1;
    final cup = Padding(
      padding: EdgeInsets.all(pad),
      child: Lottie.asset(AppLottie.coffeeCup, fit: BoxFit.contain),
    );

    final url = imageUrl;
    final Widget content = (url != null && url.isNotEmpty)
        ? Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : cup,
            errorBuilder: (_, __, ___) => cup,
          )
        : cup;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: content,
    );
  }
}

/// Empty-state placeholder: a gently floating cup over a label and optional
/// call-to-action. Replaces the static icon/text empty views.
class LottieEmpty extends StatelessWidget {
  const LottieEmpty({
    super.key,
    required this.message,
    this.action,
    this.size = 160,
  });

  final String message;
  final Widget? action;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset(AppLottie.empty, width: size, height: size),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}

/// Decorative drifting-steam band for the bottom of a screen. Non-interactive.
class LottieFooter extends StatelessWidget {
  const LottieFooter({super.key, this.height = 60});

  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.9,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Lottie.asset(
            AppLottie.footerSteam,
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }
}

/// Bottom-nav tab glyph. The Lottie is authored monochrome and recoloured to
/// the surrounding [IconTheme] (so it tracks NavigationBar's selected/unselected
/// colours), and springs to life once each time its tab becomes [selected].
/// At rest it sits on the animation's final frame, matching the static glyph.
class TabLottieIcon extends StatefulWidget {
  const TabLottieIcon({super.key, required this.asset, required this.selected});

  final String asset;
  final bool selected;

  @override
  State<TabLottieIcon> createState() => _TabLottieIconState();
}

class _TabLottieIconState extends State<TabLottieIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this)..value = 1;

  @override
  void didUpdateWidget(TabLottieIcon old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final color = iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
    final size = iconTheme.size ?? 24;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcATop),
      child: Lottie.asset(
        widget.asset,
        controller: _controller,
        width: size,
        height: size,
        onLoaded: (composition) {
          _controller.duration = composition.duration;
          if (widget.selected) _controller.forward(from: 0);
        },
      ),
    );
  }
}

/// Floating cart button: a Lottie bag glyph with an item-count badge. Shown by
/// [HomeShell] only when the cart is non-empty, and reused for the cart entry
/// point everywhere. Presentational — the count and tap handler are injected.
class CartFab extends StatelessWidget {
  const CartFab({super.key, required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Badge.count(
      count: count,
      child: FloatingActionButton(
        onPressed: onPressed,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: TabLottieIcon(asset: AppLottie.tabCart, selected: true),
        ),
      ),
    );
  }
}
