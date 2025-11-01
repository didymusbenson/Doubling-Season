## PHASE 5: POLISH & BUG FIXES

**Objective:** Final polish, gradient borders, gesture refinements, testing, and platform optimization.

**Estimated Time:** Week 5 (10-14 hours)

### 5.1 Gradient Border Implementation

**Decision**: Use gradient_borders package for simplicity.

Add to `pubspec.yaml`:
```yaml
dependencies:
  gradient_borders: ^1.0.0
```

Update `token_card.dart`:

```dart
import 'package:gradient_borders/gradient_borders.dart';

// In TokenCard decoration:
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(12),
    border: GradientBoxBorder(
      gradient: ColorUtils.gradientForColors(
        widget.item.colors,
        isEmblem: widget.item.isEmblem,
      ),
      width: 5,
    ),
    boxShadow: [ /* ... */ ],
  ),
  // ...
)
```

**Alternative: Custom Painter** (if package doesn't work):

```dart
class GradientBorderPainter extends CustomPainter {
  final Gradient gradient;
  final double width;
  final double radius;

  GradientBorderPainter({
    required this.gradient,
    required this.width,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(GradientBorderPainter oldDelegate) => false;
}

// Usage in TokenCard:
CustomPaint(
  painter: GradientBorderPainter(
    gradient: ColorUtils.gradientForColors(widget.item.colors),
    width: 5,
    radius: 12,
  ),
  child: Container(/* ... */),
)
```

**Checklist:**
- [ ] Gradient border package added or CustomPainter implemented
- [ ] Color gradients display correctly (WUBRG)
- [ ] Emblems have transparent borders
- [ ] Borders render smoothly on all devices

---

### 5.2 Screen Timeout Disable

Add to `pubspec.yaml`:
```yaml
dependencies:
  wakelock_plus: ^1.1.0
```

Update `main.dart`:

```dart
import 'package:wakelock_plus/wakelock_plus.dart';

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableWakelock();
  }

  void _enableWakelock() async {
    await WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ...
}
```

**Checklist:**
- [ ] Wakelock package added
- [ ] Screen stays awake during gameplay
- [ ] Wakelock disabled on app close

---

### 5.3 Animation Refinements

Ensure all animations match SwiftUI timing:

```dart
// Standard duration
const Duration standardDuration = Duration(milliseconds: 300);

// Token card fade-in
AnimatedOpacity(
  opacity: widget.item.amount == 0 ? 0.5 : 1.0,
  duration: standardDuration,
  child: /* ... */,
)

// MultiplierView expand/collapse
AnimatedSwitcher(
  duration: standardDuration,
  transitionBuilder: (child, animation) {
    return ScaleTransition(
      scale: animation,
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  },
  child: /* ... */,
)

// Token creation (slide up from bottom)
SlideTransition(
  position: Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: animation,
    curve: Curves.easeInOut,
  )),
  child: /* ... */,
)
```

**Checklist:**
- [ ] All animations use 300ms duration
- [ ] Curves match SwiftUI (easeInOut)
- [ ] No janky animations
- [ ] 60fps maintained during animations

---

### 5.4 Dark Mode Verification

Test all screens in dark mode and adjust colors if needed:

```dart
// In main.dart theme configuration
darkTheme: ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
  cardColor: const Color(0xFF1E1E1E), // Slightly lighter than scaffold
  scaffoldBackgroundColor: const Color(0xFF121212),
),
```

**Checklist:**
- [ ] All text readable in dark mode
- [ ] Counter pills have sufficient contrast
- [ ] Card backgrounds visible
- [ ] Visual parity with SwiftUI dark mode

---

### 5.5 Edge Case Handling

Address all edge cases:

```dart
// Empty name validation
if (nameController.text.trim().isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Token name cannot be empty')),
  );
  return;
}

// Very long names (text overflow)
Text(
  token.name,
  overflow: TextOverflow.ellipsis,
  maxLines: 2,
)

// Zero amount (opacity change)
Opacity(
  opacity: item.amount == 0 ? 0.5 : 1.0,
  child: /* ... */,
)

// Negative value prevention (already in Item model setters)
set amount(int value) {
  _amount = value < 0 ? 0 : value;
  save();
}
```

**Checklist:**
- [ ] Empty names rejected
- [ ] Long names truncated with ellipsis
- [ ] Zero amounts show opacity
- [ ] Negative values prevented
- [ ] Multiplier clamped to 1-1024
- [ ] Counter amounts can't go negative

---

### 5.6 Performance Optimization

Verify all optimizations:

```dart
// Fixed itemExtent for ListView (Phase 2)
ListView.builder(
  itemExtent: 120, // CRITICAL for 60fps
  // ...
)

// ValueListenableBuilder for reactive updates (Phase 2)
ValueListenableBuilder<Box<Item>>(
  valueListenable: provider.listenable,
  builder: (context, box, _) {
    // Only rebuilds when box changes
  },
)

// compute() for JSON parsing (Phase 1)
_allTokens = await compute(_parseTokens, jsonString);

// LazyBox for decks (Phase 1)
LazyBox<Deck> _decksBox;
```

**Checklist:**
- [ ] Scrolling 60fps with 100+ tokens
- [ ] No dropped frames during interactions
- [ ] Memory usage stable
- [ ] Hot reload works without data loss

---

### 5.7 About Screen

Create `lib/screens/about_screen.dart`:

```dart
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(
            radius: 50,
            child: Icon(Icons.token, size: 50),
          ),
          const SizedBox(height: 20),
          const Text(
            'Doubling Season',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Version 1.0.0',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          const Text(
            'A Magic: The Gathering token tracker for iOS and Android.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Features'),
            subtitle: Text(
              '• 300+ token database\n'
              '• Tap/untap tracking\n'
              '• Summoning sickness\n'
              '• Counter management\n'
              '• Deck save/load\n'
              '• Multiplier system',
            ),
          ),
          const SizedBox(height: 16),
          const ListTile(
            leading: Icon(Icons.bug_report),
            title: Text('Report Issues'),
            subtitle: Text('Contact support for bugs or feature requests'),
          ),
          const SizedBox(height: 16),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Open Source'),
            subtitle: Text('Built with Flutter'),
          ),
        ],
      ),
    );
  }
}
```

**Checklist:**
- [ ] About screen accessible from toolbar
- [ ] Version number displayed
- [ ] Feature list shown
- [ ] Contact information provided

---

### Phase 5 Final Validation

**Complete Manual Testing Checklist:**

#### Functional Tests
- [ ] Create token from database
- [ ] Create custom token
- [ ] Add/remove tokens (single and bulk)
- [ ] Tap/untap tokens (single and bulk)
- [ ] Apply summoning sickness
- [ ] Clear summoning sickness
- [ ] Add +1/+1 counters
- [ ] Add -1/-1 counters (verify auto-cancellation)
- [ ] Add custom counters
- [ ] Remove counters
- [ ] Split stack (preserve counters)
- [ ] Split stack (don't copy counters)
- [ ] Save deck
- [ ] Load deck
- [ ] Delete deck
- [ ] Search tokens (All tab)
- [ ] Search tokens (Recent tab)
- [ ] Search tokens (Favorites tab)
- [ ] Toggle favorite
- [ ] Filter by category
- [ ] Multiplier adjust (1-1024)
- [ ] Create tapped toggle
- [ ] Edit token name
- [ ] Edit token P/T
- [ ] Edit token colors
- [ ] Edit token abilities
- [ ] Scute Swarm double button
- [ ] Board wipe (set to zero)
- [ ] Board wipe (delete all)
- [ ] Swipe to delete token
- [ ] App restart (data persists)

#### Visual Tests
- [ ] Gradient borders display (WUBRG)
- [ ] Emblem centered layout (no tapped UI)
- [ ] Counter pills high contrast
- [ ] Empty states appropriate messages
- [ ] Loading spinners centered
- [ ] Error states with retry button
- [ ] Modified P/T highlighted blue
- [ ] Zero amount opacity change
- [ ] Dark mode rendering
- [ ] All icons correct (per CLAUDE.md)
- [ ] MultiplierView overlay doesn't block tokens

#### Performance Tests
- [ ] Create 100+ tokens
- [ ] Scroll smoothly (60fps)
- [ ] Rapid add/remove operations
- [ ] App memory stable after 30min gameplay
- [ ] No crashes during stress test

#### Edge Case Tests
- [ ] Empty token name rejected
- [ ] Negative amounts prevented
- [ ] Very long token names truncated
- [ ] Split stack with zero validation
- [ ] Counter amounts clamped correctly
- [ ] Tapped exceeds amount (auto-capped)
- [ ] Summoning sick exceeds amount (auto-capped)
- [ ] Maximum multiplier (1024) enforced
- [ ] Screen timeout disabled during play

---

