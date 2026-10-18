import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/closetx_repository.dart';
import '../models/account.dart';
import '../models/garment.dart';
import '../state/closet_store.dart';
import '../state/session_store.dart';
import '../supabase/supabase_config.dart';
import '../theme.dart';
import '../widgets/closet_widgets.dart';
import '../widgets/tryon_view.dart';

String _friendlyError(Object error) {
  if (error is AuthException) return error.message;
  if (error is PostgrestException) {
    if (error.code == '23505') return 'That brand name is already taken.';
    return error.message;
  }
  if (error is StorageException) return error.message;
  return error.toString();
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

const _maxImageBytes = 10 * 1024 * 1024;

/// Lets the designer pick a PNG, JPEG or WebP up to 10 MB from the gallery.
Future<DesignImage?> _pickImage(
  BuildContext context,
  ImagePicker picker, {
  double maxDimension = 2048,
}) async {
  final file = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: maxDimension,
    maxHeight: maxDimension,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final name = file.name.toLowerCase();
  final mimeType = switch (file.mimeType) {
    'image/png' || 'image/jpeg' || 'image/webp' => file.mimeType!,
    _ when name.endsWith('.png') => 'image/png',
    _ when name.endsWith('.webp') => 'image/webp',
    _ when name.endsWith('.jpg') || name.endsWith('.jpeg') => 'image/jpeg',
    _ => null,
  };
  if (!context.mounted) return null;
  if (mimeType == null) {
    _showMessage(context, 'Choose a PNG, JPEG or WebP image.');
    return null;
  }
  if (bytes.length > _maxImageBytes) {
    _showMessage(context, 'Images must be 10 MB or smaller.');
    return null;
  }
  return DesignImage(bytes: bytes, fileName: file.name, mimeType: mimeType);
}

/// Reloads the public catalog after a designer changes their designs.
Future<void> refreshCatalog(BuildContext context) {
  if (!isSupabaseConfigured) return Future.value();
  return ClosetStoreScope.of(
    context,
  ).loadCatalog(ClosetXRepository().loadPublishedDesigns);
}

// ---------------------------------------------------------------------------
// Sign in / create account
// ---------------------------------------------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.onContinue,
    this.shopperOnly = false,
    super.key,
  });

  /// Called when the person continues as a guest or finishes signing in.
  final VoidCallback onContinue;
  final bool shopperOnly;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isCreatingAccount = false;
  bool _isBusy = false;
  AccountRole _role = AccountRole.shopper;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreatingAccount ? 'Create account' : 'Sign in'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ClosetLogo(),
                    const SizedBox(height: 24),
                    Text(
                      _isCreatingAccount ? 'Join ClosetX.' : 'Welcome back.',
                      style: headingStyle(29),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isCreatingAccount
                          ? widget.shopperOnly
                                ? 'Create a shopper account to save designs and keep your favourites together.'
                                : _role == AccountRole.designer
                                ? 'Create a designer account to set up your brand and upload your designs.'
                                : 'Create a shopper account to save designs and keep your favourites together.'
                          : widget.shopperOnly
                          ? 'Sign in with your shopper account to save this design.'
                          : 'Sign in to keep your favourite local finds together.',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 26),
                    if (_isCreatingAccount) ...[
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) => (value?.trim() ?? '').isEmpty
                            ? 'Enter your name.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Enter your email address.';
                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(email)) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter your password.';
                        }
                        if (_isCreatingAccount && value.length < 6) {
                          return 'Use at least 6 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _isBusy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: ink,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                      ),
                      child: _isBusy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isCreatingAccount ? 'Create account' : 'Sign in',
                            ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isBusy ? null : _toggleAccountMode,
                      child: Text(
                        _isCreatingAccount
                            ? 'Already have an account? Sign in'
                            : 'New to ClosetX? Create an account',
                      ),
                    ),
                    const Divider(height: 24),
                    FilledButton.tonalIcon(
                      onPressed: widget.onContinue,
                      icon: const Icon(Icons.explore_outlined),
                      label: const Text('Continue browsing as a guest'),
                      style: FilledButton.styleFrom(
                        backgroundColor: sage,
                        foregroundColor: ink,
                        minimumSize: const Size(0, 52),
                        side: const BorderSide(color: accent, width: 1),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleAccountMode() async {
    if (_isCreatingAccount) {
      setState(() => _isCreatingAccount = false);
      return;
    }

    if (widget.shopperOnly) {
      setState(() {
        _role = AccountRole.shopper;
        _isCreatingAccount = true;
      });
      return;
    }

    final role = await showDialog<AccountRole>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('How will you use ClosetX?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shopping_bag_outlined),
              title: const Text('Shopper'),
              subtitle: const Text('Save designs and keep your favourites.'),
              onTap: () => Navigator.of(dialogContext).pop(AccountRole.shopper),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.design_services_outlined),
              title: const Text('Designer'),
              subtitle: const Text('Create a brand and upload your designs.'),
              onTap: () =>
                  Navigator.of(dialogContext).pop(AccountRole.designer),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || role == null) return;
    setState(() {
      _role = role;
      _isCreatingAccount = true;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final session = SessionScope.of(context);
    setState(() => _isBusy = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (_isCreatingAccount) {
        final isDesignerApplication = _role == AccountRole.designer;
        final outcome = await session.signUp(
          email: email,
          password: password,
          fullName: _nameController.text.trim(),
          role: _role,
        );
        if (!mounted) return;
        if (outcome == SignUpOutcome.confirmEmail) {
          setState(() => _isCreatingAccount = false);
          if (isDesignerApplication) {
            await _showDesignerApplicationSubmitted(
              context,
              email,
              needsEmailConfirmation: true,
            );
          } else {
            _showMessage(
              context,
              'Check $email for a confirmation link, then sign in.',
            );
          }
          return;
        }
        if (isDesignerApplication) {
          await _showDesignerApplicationSubmitted(context, email);
          if (!mounted) return;
        }
      } else {
        await session.signIn(email: email, password: password);
      }
      if (mounted) widget.onContinue();
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}

Future<void> _showDesignerApplicationSubmitted(
  BuildContext context,
  String email, {
  bool needsEmailConfirmation = false,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Application submitted'),
      content: Text(
        needsEmailConfirmation
            ? 'Your designer application is pending review. Confirm your email '
                  'using the link sent to $email, then sign in. We’ll email you '
                  'when an admin accepts or declines your application.'
            : 'Your designer application is pending review. We’ll email $email '
                  'when an admin accepts or declines your application.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

Future<void> toggleSavedGarment(BuildContext context, Garment garment) async {
  final session = SessionScope.of(context);
  if (!session.isSignedIn) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => LoginScreen(
          shopperOnly: true,
          onContinue: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
    if (!context.mounted) return;
  }

  await session.ensureProfileLoaded();
  if (!context.mounted) return;
  if (session.loadError != null) {
    _showMessage(
      context,
      'Could not verify your shopper account: ${_friendlyError(session.loadError!)}',
    );
    return;
  }
  if (!session.isShopper || session.userId == null) {
    _showMessage(context, 'Sign in with a shopper account to save designs.');
    return;
  }
  if (!garment.id.startsWith('supabase:')) {
    _showMessage(context, 'This design cannot be saved right now.');
    return;
  }

  final store = ClosetStoreScope.of(context);
  final isSaved = store.isSaved(garment);
  try {
    await ClosetXRepository().setDesignSaved(
      shopperId: session.userId!,
      designId: garment.id.substring('supabase:'.length),
      isSaved: !isSaved,
    );
    if (context.mounted) store.toggleSaved(garment);
  } catch (error) {
    if (context.mounted) _showMessage(context, _friendlyError(error));
  }
}

// ---------------------------------------------------------------------------
// Brand
// ---------------------------------------------------------------------------

class BrandEditorScreen extends StatefulWidget {
  const BrandEditorScreen({super.key});

  @override
  State<BrandEditorScreen> createState() => _BrandEditorScreenState();
}

class _BrandEditorScreenState extends State<BrandEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;
  final _picker = ImagePicker();
  DesignImage? _logo;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final brand = SessionScope.of(context).brand;
    _nameController = TextEditingController(text: brand?.name);
    _bioController = TextEditingController(text: brand?.bio);
    _locationController = TextEditingController(text: brand?.location);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = SessionScope.of(context).brand;
    final isNew = brand == null;
    final logo = _logo;
    final savedLogoUrl = brand?.hasLogo ?? false ? brand!.logoUrl : null;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'Create your brand' : 'Edit brand')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            const Text(
              'YOUR LABEL',
              style: TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text('Tell shoppers\nwho you are.', style: headingStyle(29)),
            const SizedBox(height: 22),
            Row(
              children: [
                Semantics(
                  button: true,
                  label: logo == null && savedLogoUrl == null
                      ? 'Add brand logo'
                      : 'Replace brand logo',
                  child: InkWell(
                    onTap: _isSaving ? null : _pickLogo,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: line),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: logo != null
                          ? Image.memory(logo.bytes, fit: BoxFit.cover)
                          : savedLogoUrl != null
                          ? Image.network(savedLogoUrl, fit: BoxFit.cover)
                          : const Icon(
                              Icons.add_photo_alternate_outlined,
                              color: muted,
                              size: 28,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Brand logo',
                        style: TextStyle(
                          color: ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Shown next to your brand name on every shirt. A square image works best.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Brand name',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.length < 2) return 'Use at least 2 characters.';
                if (name.length > 60) return 'Keep it under 60 characters.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _locationController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _bioController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'About the brand (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: ink,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
              ),
              child: _isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isNew ? 'Create brand' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLogo() async {
    final logo = await _pickImage(context, _picker, maxDimension: 1024);
    if (logo != null && mounted) setState(() => _logo = logo);
  }

  Future<void> _save() async {
    final formValid = _formKey.currentState!.validate();
    final session = SessionScope.of(context);
    if (_logo == null && !(session.brand?.hasLogo ?? false)) {
      _showMessage(context, 'Add your brand logo.');
      return;
    }
    if (!formValid) return;
    setState(() => _isSaving = true);
    try {
      await session.saveBrand(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        logo: _logo,
      );
      if (!mounted) return;
      await refreshCatalog(context);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Designer studio: list and delete own designs
// ---------------------------------------------------------------------------

class DesignerStudioScreen extends StatefulWidget {
  const DesignerStudioScreen({super.key});

  @override
  State<DesignerStudioScreen> createState() => _DesignerStudioScreenState();
}

class _DesignerStudioScreenState extends State<DesignerStudioScreen> {
  final _repository = ClosetXRepository();
  List<DesignerDesign>? _designs;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = SessionScope.of(context).userId;
    if (userId == null) return;
    setState(() => _error = null);
    try {
      final designs = await _repository.loadMyDesigns(userId);
      if (mounted) setState(() => _designs = designs);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _upload() async {
    if (!(SessionScope.of(context).brand?.hasLogo ?? false)) {
      _showMessage(context, 'Add your brand logo before uploading designs.');
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const BrandEditorScreen()),
      );
      if (!mounted || !(SessionScope.of(context).brand?.hasLogo ?? false)) {
        return;
      }
    }
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const UploadDesignScreen()));
    if (created == true && mounted) {
      await _load();
      if (mounted) await refreshCatalog(context);
    }
  }

  Future<void> _togglePublished(DesignerDesign design) async {
    try {
      await _repository.setPublished(design.id, !design.isPublished);
      await _load();
      if (mounted) await refreshCatalog(context);
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    }
  }

  Future<void> _delete(DesignerDesign design) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete design?'),
        content: Text(
          '"${design.garment.name}" and its artwork will be removed for good.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteDesign(design);
      await _load();
      if (mounted) await refreshCatalog(context);
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = SessionScope.of(context).brand;
    final designs = _designs;

    return Scaffold(
      appBar: AppBar(
        title: Text(brand?.name ?? 'Your studio'),
        actions: [
          IconButton(
            tooltip: 'Edit brand',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BrandEditorScreen(),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        backgroundColor: ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Upload design'),
      ),
      body: _error != null
          ? EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load your designs',
              message: _friendlyError(_error!),
            )
          : designs == null
          ? const Center(child: CircularProgressIndicator())
          : designs.isEmpty
          ? const EmptyState(
              icon: Icons.checkroom_outlined,
              title: 'No designs yet',
              message:
                  'Upload the front and back artwork of your first shirt to see it in 3D.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                itemCount: designs.length,
                separatorBuilder: (_, _) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final design = designs[index];
                  final garment = design.garment;
                  return Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: SizedBox(
                          width: 76,
                          height: 92,
                          child: FashionImage(
                            imageUrl: garment.imageUrl,
                            background: garment.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              garment.name,
                              style: const TextStyle(
                                color: ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${garment.formattedPrice} · ${garment.category}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${design.saveCount} ${design.saveCount == 1 ? 'shopper' : 'shoppers'} saved this',
                              style: const TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              design.reviewStatus == 'pending'
                                  ? 'Pending admin review'
                                  : design.reviewStatus == 'rejected'
                                  ? 'Not approved'
                                  : design.isPublished
                                  ? 'Published'
                                  : 'Hidden',
                              style: TextStyle(
                                color: design.reviewStatus == 'rejected'
                                    ? Colors.red.shade700
                                    : design.reviewStatus == 'approved' &&
                                          design.isPublished
                                    ? accent
                                    : muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (design.rejectionReason?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                design.rejectionReason!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Design options',
                        onSelected: (value) {
                          if (value == 'delete') {
                            _delete(design);
                          } else {
                            _togglePublished(design);
                          }
                        },
                        itemBuilder: (context) => [
                          if (design.reviewStatus == 'approved')
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(
                                design.isPublished
                                    ? 'Hide from shop'
                                    : 'Publish to shop',
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upload a design: front/back artwork, shirt colour, live 3D preview
// ---------------------------------------------------------------------------

const _shirtColors = <String, Color>{
  '#F2F2F2': Color(0xFFF2F2F2),
  '#26251F': Color(0xFF26251F),
  '#B46750': Color(0xFFB46750),
  '#8E9A7B': Color(0xFF8E9A7B),
  '#2F4A6D': Color(0xFF2F4A6D),
  '#E8D9C0': Color(0xFFE8D9C0),
  '#A33A3A': Color(0xFFA33A3A),
};

const _designCategories = ['T-Shirts', 'Graphic Tees', 'Oversized Tees'];

class UploadDesignScreen extends StatefulWidget {
  const UploadDesignScreen({super.key});

  @override
  State<UploadDesignScreen> createState() => _UploadDesignScreenState();
}

class _UploadDesignScreenState extends State<UploadDesignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _picker = ImagePicker();
  String _category = _designCategories.first;
  String _shirtColor = _shirtColors.keys.first;
  DesignImage? _thumbnail;
  DesignImage? _front;
  DesignImage? _back;
  String? _frontPreviewUrl;
  String? _backPreviewUrl;
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    for (final url in [_frontPreviewUrl, _backPreviewUrl]) {
      if (url != null) revokePreviewUrl(url);
    }
    super.dispose();
  }

  Future<void> _pickThumbnail() async {
    final image = await _pickImage(context, _picker);
    if (image != null && mounted) setState(() => _thumbnail = image);
  }

  Future<void> _pick({required bool front}) async {
    final image = await _pickImage(context, _picker);
    if (image == null || !mounted) return;
    final previewUrl = createPreviewUrl(image.bytes, image.mimeType);
    setState(() {
      if (front) {
        if (_frontPreviewUrl != null) revokePreviewUrl(_frontPreviewUrl!);
        _front = image;
        _frontPreviewUrl = previewUrl;
      } else {
        if (_backPreviewUrl != null) revokePreviewUrl(_backPreviewUrl!);
        _back = image;
        _backPreviewUrl = previewUrl;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload a design')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            Text('Your shirt,\nin 3D.', style: headingStyle(29)),
            const SizedBox(height: 8),
            const Text(
              'Add a product photo for the shop, then the front and back artwork for the 3D shirt.',
              style: TextStyle(color: muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 18),
            const Text(
              'Product photo',
              style: TextStyle(
                color: ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'The thumbnail shoppers see in the featured list, e.g. a photo of the finished shirt.',
              style: TextStyle(color: muted, fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 10),
            Center(
              child: SizedBox(
                width: 200,
                child: _ArtworkPicker(
                  label: 'Photo',
                  image: _thumbnail,
                  height: 250,
                  cover: true,
                  onTap: _pickThumbnail,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Shirt artwork',
              style: TextStyle(
                color: ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'PNGs with a transparent background print cleanest on the shirt.',
              style: TextStyle(color: muted, fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ArtworkPicker(
                    label: 'Front',
                    image: _front,
                    onTap: () => _pick(front: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ArtworkPicker(
                    label: 'Back',
                    image: _back,
                    onTap: () => _pick(front: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Shirt colour',
              style: TextStyle(
                color: ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final MapEntry(key: hex, value: color)
                    in _shirtColors.entries)
                  Semantics(
                    label: 'Shirt colour $hex',
                    selected: _shirtColor == hex,
                    button: true,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _shirtColor = hex),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _shirtColor == hex ? accent : line,
                            width: _shirtColor == hex ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (isTryOnSupported) ...[
              const SizedBox(height: 18),
              const Text(
                '3D preview',
                style: TextStyle(
                  color: ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 340,
                  child: TryOnView(
                    src: tryOnPageUrl(
                      mode: TryOnMode.viewer3d,
                      frontImageUrl: _frontPreviewUrl,
                      backImageUrl: _backPreviewUrl,
                      shirtColorHex: _shirtColor,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            TextFormField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Design name'),
              validator: (value) {
                final title = value?.trim() ?? '';
                if (title.length < 2) return 'Use at least 2 characters.';
                if (title.length > 80) return 'Keep it under 80 characters.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Price',
                prefixText: '₱ ',
              ),
              validator: (value) {
                final price = int.tryParse(value?.trim() ?? '');
                if (price == null || price < 0) {
                  return 'Enter a price in whole pesos.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final category in _designCategories)
                  DropdownMenuItem(value: category, child: Text(category)),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _isUploading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: ink,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
              ),
              icon: _isUploading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_isUploading ? 'Uploading…' : 'Submit for review'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState!.validate();
    final thumbnail = _thumbnail, front = _front, back = _back;
    if (thumbnail == null) {
      _showMessage(context, 'Add a product photo for the shop thumbnail.');
      return;
    }
    if (front == null || back == null) {
      _showMessage(context, 'Add both the front and back artwork.');
      return;
    }
    if (!formValid) return;

    final session = SessionScope.of(context);
    final userId = session.userId, brand = session.brand;
    if (userId == null || brand == null) {
      _showMessage(context, 'Create your brand before uploading designs.');
      return;
    }

    setState(() => _isUploading = true);
    try {
      await ClosetXRepository().createDesign(
        userId: userId,
        brand: brand,
        design: NewDesign(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: int.parse(_priceController.text.trim()),
          category: _category,
          shirtColorHex: _shirtColor,
          thumbnail: thumbnail,
          front: front,
          back: back,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}

class _ArtworkPicker extends StatelessWidget {
  const _ArtworkPicker({
    required this.label,
    required this.image,
    required this.onTap,
    this.height = 150,
    this.cover = false,
  });

  final String label;
  final DesignImage? image;
  final VoidCallback onTap;
  final double height;

  /// Fill the box with the photo instead of fitting artwork inside it.
  final bool cover;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    return Semantics(
      button: true,
      label: image == null ? 'Add $label artwork' : 'Replace $label artwork',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null && cover)
                Padding(
                  padding: const EdgeInsets.only(bottom: 34),
                  child: Image.memory(image.bytes, fit: BoxFit.cover),
                )
              else if (image != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 34),
                  child: Image.memory(image.bytes, fit: BoxFit.contain),
                )
              else
                const Center(
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: muted,
                    size: 30,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: Text(
                  image == null ? 'Add $label' : '$label · tap to replace',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  final _repository = ClosetXRepository();
  int _rating = 5;
  bool _isSending = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final profile = SessionScope.of(context).profile;
    _nameController.text = profile?.fullName ?? '';
    _emailController.text = profile?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share feedback')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            Text('Help us make ClosetX better.', style: headingStyle(26)),
            const SizedBox(height: 8),
            const Text(
              'Your feedback goes directly to the ClosetX team.',
              style: TextStyle(color: muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 22),
            DropdownButtonFormField<int>(
              initialValue: _rating,
              decoration: const InputDecoration(labelText: 'Your rating'),
              items: [
                for (var rating = 5; rating >= 1; rating--)
                  DropdownMenuItem(
                    value: rating,
                    child: Text('$rating ${rating == 1 ? 'star' : 'stars'}'),
                  ),
              ],
              onChanged: _isSending
                  ? null
                  : (rating) => setState(() => _rating = rating ?? _rating),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _messageController,
              minLines: 5,
              maxLines: 8,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Feedback',
                alignLabelWithHint: true,
                hintText: 'What is working well, or what could be improved?',
              ),
              validator: (value) {
                final message = value?.trim() ?? '';
                if (message.isEmpty) return 'Write a short message first.';
                if (message.length > 2000) {
                  return 'Keep it under 2,000 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nameController,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Name (optional)'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                helperText: 'Include an email if you would like a reply.',
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isNotEmpty &&
                    !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _isSending ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: ink,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
              ),
              icon: _isSending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_isSending ? 'Sending…' : 'Send feedback'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!isSupabaseConfigured) {
      _showMessage(context, 'Feedback needs a configured ClosetX project.');
      return;
    }
    setState(() => _isSending = true);
    try {
      await _repository.submitFeedback(
        authorName: _nameController.text,
        authorEmail: _emailController.text,
        message: _messageController.text,
        rating: _rating,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Thanks for sharing your feedback.')),
      );
    } catch (error) {
      if (mounted) _showMessage(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
