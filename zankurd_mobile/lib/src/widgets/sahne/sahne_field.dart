import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_icons.dart';
import '../../theme/sahne.dart';

/// Şahnê girdi alanları: uygulamadaki TEK metin girdisi, arama kutusu ve
/// açılır liste biçimi.
///
/// Niçin tek yerde: giriş ekranları pahlı alanı kullanıyor, ad kapısı, ayarlar,
/// soru öneri formu, sözlük ve arkadaş araması ise Material'in yuvarlak
/// kutusunu (2026-09-30 dört bağımsız denetçi aynı kusuru buldu). Etiket
/// rengi ve yer tutucu stili de formdan forma değişiyordu. Biçim artık
/// burada; ekranlar `TextField`/`DropdownButton` yazmaz
/// (`test/sahne_field_guard_test.dart` bunu kaynak taramasıyla korur).
///
/// Biçim kararları:
/// * Zemin Kulis (`s2`) — alan çoğunlukla bir Perde kartının içinde durur;
///   M pah. Dinlenirken gündüzde 1 px `edge`, gecede kenarsız (katman tonla
///   ayrılır).
/// * Odak: Agir (`actTx`) Halka 2. Hata: Şaş (`errTx`) Halka 2 + altında
///   Şaş metni; hata hiçbir zaman yalnız renkle verilmez, metni vardır.
/// * Etiket her yerde `captionStrong` + `tx2`, alanın ÜSTÜNDE; yer tutucu
///   her yerde `body` + `tx3` (açılır listenin "Bir konu seç"i dahil).
/// * Hepsi `Form` ile konuşur: `Form.validate()` çalışır, ayrıca
///   `GlobalKey<SahneFieldState>().currentState!.validate()` ile Form'suz da.
class SahneField extends FormField<String> {
  SahneField({
    super.key,
    this.label,
    this.controller,
    this.focusNode,
    this.hintText,
    this.semanticLabel,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.autofocus = false,
    this.minLines,
    this.maxLines = 1,
    this.minHeight = 52,
    this.prefixIcon,
    this.leading,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.suffixSemanticLabel,
    this.inputTextStyle,
    this.onChanged,
    this.onSubmitted,
    super.validator,
    super.autovalidateMode,
    super.enabled,
  }) : super(
         initialValue: controller?.text ?? '',
         builder: (field) => (field as SahneFieldState)._buildField(),
       );

  /// Arama kutusu: baştaki büyüteç, klavyede "ara" tuşu. Etiketsizdir
  /// (ipucu soruyu söyler); ekran okuyucu için [semanticLabel] verilir.
  SahneField.search({
    Key? key,
    TextEditingController? controller,
    String? hintText,
    String? semanticLabel,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    bool enabled = true,
  }) : this(
         key: key,
         controller: controller,
         hintText: hintText,
         semanticLabel: semanticLabel ?? hintText,
         textInputAction: TextInputAction.search,
         prefixIcon: AppIcons.magnifyingGlass,
         onChanged: onChanged,
         onSubmitted: onSubmitted,
         enabled: enabled,
       );

  /// Alanın üstündeki etiket. Boşsa etiket satırı hiç çizilmez.
  final String? label;

  /// Verilmezse alan kendi denetleyicisini kurar.
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Alan boşken görünen yer tutucu.
  final String? hintText;

  /// Etiketsiz alanlarda ekran okuyucunun söyleyeceği ad.
  final String? semanticLabel;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool autofocus;
  final int? minLines;
  final int maxLines;

  /// Tek satırlı alanın en az yüksekliği (dokunma hedefi için 48+).
  final double minHeight;

  /// Baştaki ikon (20). [leading] verilirse o kullanılır.
  final IconData? prefixIcon;

  /// Baştaki özel öğe (ör. cevap alanındaki harf rozeti).
  final Widget? leading;

  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final String? suffixSemanticLabel;

  /// Yazı stili; yoksa `SahneType.body` + birincil metin. Yalnız gerçekten
  /// farklı yazan alan (ör. harf aralıklı oda kodu) verir.
  final TextStyle? inputTextStyle;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  FormFieldState<String> createState() => SahneFieldState();
}

class SahneFieldState extends FormFieldState<String> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;

  SahneField get _field => widget as SahneField;

  TextEditingController get _controller =>
      _field.controller ?? (_ownController ??= TextEditingController());

  FocusNode get _focusNode =>
      _field.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant FormField<String> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget as SahneField;
    if (old.focusNode != _field.focusNode) {
      (old.focusNode ?? _ownFocusNode)?.removeListener(_onFocusChange);
      _focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _ownFocusNode?.dispose();
    _ownController?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  /// Denetleyiciye ekranın dışından yazılmış olabilir (ör. gönderince
  /// `clear()`); doğrulama alanın değil denetleyicinin metnini görmeli.
  @override
  bool validate() {
    setValue(_controller.text);
    return super.validate();
  }

  @override
  void didChange(String? value) {
    super.didChange(value);
    if (_controller.text != (value ?? '')) _controller.text = value ?? '';
  }

  @override
  void reset() {
    _controller.text = _field.initialValue ?? '';
    super.reset();
  }

  void _handleChanged(String value) {
    didChange(value);
    _field.onChanged?.call(value);
  }

  Widget _buildField() {
    final t = SahneTokens.of(context);
    final w = _field;
    final error = errorText;
    final hasError = error != null && error.isNotEmpty;
    final focused = _focusNode.hasFocus;
    final enabled = w.enabled;
    final multiline = w.maxLines > 1 || (w.minLines ?? 1) > 1;

    final textStyle = (w.inputTextStyle ?? SahneType.body).copyWith(
      color: enabled ? t.tx : t.tx3,
    );
    final iconColor = hasError
        ? t.errTx
        : focused
        ? t.tx
        : t.tx2;

    Widget? leading = w.leading;
    if (leading == null && w.prefixIcon != null) {
      leading = Icon(w.prefixIcon, size: 20, color: iconColor);
    }

    return _SahneFieldShell(
      label: w.label,
      error: hasError ? error : null,
      child: _SahneFieldFrame(
        focused: focused,
        hasError: hasError,
        enabled: enabled,
        minHeight: w.minHeight,
        alignTop: multiline,
        leading: leading,
        trailing: w.suffixIcon == null
            ? null
            : Semantics(
                label: w.suffixSemanticLabel,
                button: w.onSuffixIconPressed != null,
                enabled: w.onSuffixIconPressed != null,
                onTap: w.onSuffixIconPressed,
                child: ExcludeSemantics(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: w.onSuffixIconPressed,
                      child: Icon(w.suffixIcon, size: 20, color: iconColor),
                    ),
                  ),
                ),
              ),
        child: Semantics(
          label: (w.label != null && w.label!.isNotEmpty)
              ? w.label
              : w.semanticLabel,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: enabled,
            autofocus: w.autofocus,
            keyboardType: w.keyboardType,
            textInputAction: w.textInputAction,
            textCapitalization: w.textCapitalization,
            inputFormatters: w.inputFormatters,
            obscureText: w.obscureText,
            autocorrect: w.autocorrect,
            enableSuggestions: w.enableSuggestions,
            minLines: w.minLines,
            maxLines: w.obscureText ? 1 : w.maxLines,
            style: textStyle,
            cursorColor: hasError ? t.errTx : t.tx,
            onChanged: _handleChanged,
            onSubmitted: w.onSubmitted,
            // Çerçeveyi alan çizer; TextField'ın kendi kutusu kapalı. Bu
            // sözleşmeyi test/styled_input_test.dart (ve bekçi test) korur:
            // tema çerçevesi ikinci kez çizilirse çift kenar çıkar.
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
              hintText: w.hintText ?? '',
              hintStyle: SahneType.body.copyWith(color: t.tx3),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: SahneSpace.x3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Açılır liste: [SahneField] ile aynı çerçeve, etiket, yer tutucu ve hata
/// dili. `Form` içinde doğrulanır.
///
/// Açılan menü yuvarlak değil köşeli ve Perde (`s1`) tonunda; satır
/// yüksekliği 52 (dokunma hedefi).
class SahneDropdownField<T> extends FormField<T> {
  SahneDropdownField({
    super.key,
    this.label,
    required this.items,
    this.hintText,
    this.onChanged,
    super.initialValue,
    super.validator,
    super.autovalidateMode,
    super.enabled,
  }) : super(
         builder: (field) => _SahneDropdownBody<T>(
           field: field,
           label: label,
           items: items,
           hintText: hintText,
           onChanged: onChanged,
           enabled: enabled,
         ),
       );

  final String? label;
  final List<DropdownMenuItem<T>> items;
  final String? hintText;
  final ValueChanged<T?>? onChanged;
}

class _SahneDropdownBody<T> extends StatefulWidget {
  const _SahneDropdownBody({
    required this.field,
    required this.label,
    required this.items,
    required this.hintText,
    required this.onChanged,
    required this.enabled,
  });

  final FormFieldState<T> field;
  final String? label;
  final List<DropdownMenuItem<T>> items;
  final String? hintText;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  @override
  State<_SahneDropdownBody<T>> createState() => _SahneDropdownBodyState<T>();
}

class _SahneDropdownBodyState<T> extends State<_SahneDropdownBody<T>> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final error = widget.field.errorText;
    final hasError = error != null && error.isNotEmpty;
    final iconColor = hasError ? t.errTx : t.tx2;

    return _SahneFieldShell(
      label: widget.label,
      error: hasError ? error : null,
      child: _SahneFieldFrame(
        focused: _focusNode.hasFocus,
        hasError: hasError,
        enabled: widget.enabled,
        minHeight: 52,
        // Dokunma alanı çerçevenin tamamı: dolgu düğmenin kendisinde.
        padding: EdgeInsets.zero,
        child: Semantics(
          label: widget.label,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: widget.field.value,
              focusNode: _focusNode,
              isExpanded: true,
              itemHeight: 52,
              padding: const EdgeInsetsDirectional.only(
                start: SahneSpace.x4,
                end: SahneSpace.x3,
              ),
              icon: Icon(AppIcons.chevronDown, size: 20, color: iconColor),
              style: SahneType.body.copyWith(color: t.tx),
              dropdownColor: t.s1,
              borderRadius: BorderRadius.zero,
              focusColor: Colors.transparent,
              hint: Text(
                widget.hintText ?? '',
                style: SahneType.body.copyWith(color: t.tx3),
              ),
              items: widget.items,
              onChanged: widget.enabled
                  ? (value) {
                      widget.field.didChange(value);
                      widget.onChanged?.call(value);
                    }
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiket (üstte) + çerçeve + hata metni (altta) dizilişi; iki alan türü de
/// aynı dizilişi kullanır.
class _SahneFieldShell extends StatelessWidget {
  const _SahneFieldShell({
    required this.label,
    required this.error,
    required this.child,
  });

  final String? label;
  final String? error;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null && label!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: SahneSpace.x2),
            child: ExcludeSemantics(
              child: Text(
                label!,
                style: SahneType.captionStrong.copyWith(color: t.tx2),
              ),
            ),
          ),
        child,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(
              top: SahneSpace.x1,
              left: SahneSpace.x1,
            ),
            child: Semantics(
              liveRegion: true,
              // Hata metni KIRPILMAZ: kısaltılmış bir uyarı ("Kodê kontrol
              // bike. Mî…") ne yapılacağını söylemez; 320 px'te satır kırılır.
              child: Text(
                error!,
                overflow: TextOverflow.visible,
                style: SahneType.caption.copyWith(color: t.errTx),
              ),
            ),
          ),
      ],
    );
  }
}

/// Pahlı çerçeve. `Material` olmasının sebebi: içindeki bir `InkWell`
/// (açılır liste) çerçevenin zemininin ÜSTÜNDE ve pah içinde kırpılı çizilsin.
class _SahneFieldFrame extends StatelessWidget {
  const _SahneFieldFrame({
    required this.focused,
    required this.hasError,
    required this.enabled,
    required this.minHeight,
    required this.child,
    this.alignTop = false,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: SahneSpace.x4),
  });

  final bool focused;
  final bool hasError;
  final bool enabled;
  final double minHeight;
  final bool alignTop;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final side = hasError
        ? BorderSide(
            color: t.errTx,
            width: SahneRing.r2,
            strokeAlign: BorderSide.strokeAlignInside,
          )
        : focused
        ? BorderSide(
            color: t.actTx,
            width: SahneRing.r2,
            strokeAlign: BorderSide.strokeAlignInside,
          )
        : BorderSide(color: t.edge, strokeAlign: BorderSide.strokeAlignInside);

    return Material(
      color: t.s2,
      clipBehavior: Clip.antiAlias,
      shape: BeveledRectangleBorder(
        borderRadius: SahneShape.m.borderRadius,
        side: side,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: alignTop
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                alignTop
                    ? Padding(
                        padding: const EdgeInsets.only(top: SahneSpace.x3),
                        child: leading,
                      )
                    : leading!,
                const SizedBox(width: SahneSpace.x3),
              ],
              Expanded(child: child),
              if (trailing != null) ...[
                const SizedBox(width: SahneSpace.x2),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
