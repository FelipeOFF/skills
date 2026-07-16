import 'package:rx_notifier/rx_notifier.dart';

import 'package:app/common/base/base_controller.dart';
import 'package:app/domain/example/get_items_use_case.dart';
import 'package:app/domain/example/dto/item_dto.dart';
import 'package:app/domain/example/dto/page_params.dart';

/// A feature ViewModel. Rename the `Example`/`Item` anchors to the real names.
///
/// The rx_field idiom is the dominant repeated shape: a private `RxNotifier<T>`
/// plus a public getter and setter. The notifier stays encapsulated (the View
/// can never `.dispose()` or swap it), the public API is plain Dart
/// (`controller.items`, `controller.currentPage = 0`), and reads inside an
/// `RxBuilder` rebuild that builder automatically.
class ExampleController extends BaseController {
  final GetItemsUseCase _getItemsUseCase;

  ExampleController(this._getItemsUseCase);

  // --- reactive state: private RxNotifier + getter/setter (the rx_field idiom) ---
  final RxNotifier<List<ItemDto>> _items = RxNotifier<List<ItemDto>>(const []);
  List<ItemDto> get items => _items.value;
  set items(List<ItemDto> value) => _items.value = value;

  final RxNotifier<int> _currentPage = RxNotifier<int>(0);
  int get currentPage => _currentPage.value;
  set currentPage(int value) => _currentPage.value = value;

  final RxNotifier<bool> _hasReachedEnd = RxNotifier<bool>(false);
  bool get hasReachedEnd => _hasReachedEnd.value;
  set hasReachedEnd(bool value) => _hasReachedEnd.value = value;

  // Nullable reactive state seeds with null.
  final RxNotifier<ItemDto?> _selected = RxNotifier<ItemDto?>(null);
  ItemDto? get selected => _selected.value;
  set selected(ItemDto? value) => _selected.value = value;

  // Non-reactive scratch state stays a plain field — no rebuild needed.
  bool _isFetching = false;
  static const int _pageSize = 20;

  // Derived getter: reactive when read inside an RxBuilder because it reads
  // notifier-backed getters; combine freely.
  bool get canLoadMore => !hasReachedEnd && !_isFetching;

  /// First/refresh load. Drives the inherited `isLoading` via the ladder.
  Future<void> loadItems({bool forceRefresh = false}) async {
    final List<ItemDto>? page = await execSingle(
      const PageParams(page: 0, size: _pageSize),
      _getItemsUseCase,
      forceRefresh: forceRefresh,
    );
    if (isDisposed || page == null) return;
    currentPage = 0;
    hasReachedEnd = page.length < _pageSize;
    items = page;
  }

  /// Pagination. Manages its own fetch flag and suppresses the global spinner
  /// (`showLoading: false`) so the list keeps showing while more loads.
  Future<void> loadMore() async {
    if (!canLoadMore) return;
    _isFetching = true;
    final List<ItemDto>? page = await execSingle(
      PageParams(page: currentPage + 1, size: _pageSize),
      _getItemsUseCase,
      showLoading: false,
      mapError: (error, defaultMessage) {
        if (isDisposed) return null; // suppress after dispose
        return defaultMessage;
      },
    );
    if (isDisposed) {
      _isFetching = false;
      return;
    }
    if (page != null) {
      currentPage = currentPage + 1;
      hasReachedEnd = page.length < _pageSize;
      items = [...items, ...page];
    }
    _isFetching = false;
  }

  @override
  Future<void> dispose() async {
    _isFetching = false;
    _items.dispose(); // dispose every RxNotifier this Controller owns
    _currentPage.dispose();
    _hasReachedEnd.dispose();
    _selected.dispose();
    await super.dispose(); // disposes the base notifiers
  }
}
