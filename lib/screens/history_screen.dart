import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/ledger_filter.dart';
import '../models/period_summary.dart';
import '../models/transaction.dart';
import '../repositories/budget_repository.dart';
import '../state/ledger_filter_controller.dart';
import '../utils/app_colors.dart';
import '../widgets/payment_method_field.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  /// Free-text search over the list. A third axis beside period and category —
  /// deliberately not folded into [LedgerFilter], because Ringkasan publishes
  /// that object and would then publish whatever someone happened to type here.
  final _searchController = TextEditingController();

  /// Whether the box is being typed into. Before this the border sat in one
  /// color whether or not the cursor was in the field, so a tap that landed
  /// elsewhere left no trace and the field looked inert after the tap.
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// What a person would actually type. Merchandise and merchant are the obvious
  /// hits; `rawInput` catches anything free-form, and the categories are in
  /// because this app groups by "kantong" — searching "investasi" to find what
  /// went there is the natural thing to reach for once you know the word.
  bool _matchesQuery(TransactionRecord record, String query) {
    if (record.merchantName.toLowerCase().contains(query)) return true;
    if (record.items.toLowerCase().contains(query)) return true;
    if (record.rawInput.toLowerCase().contains(query)) return true;
    if (record.chargedTo?.toLowerCase().contains(query) ?? false) return true;
    return record.splits
        .any((s) => s.category.name.toLowerCase().contains(query));
  }

  String _fmt(double amount) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    return formatter.format(amount);
  }

  void _showTransactionOptions(BuildContext context, TransactionRecord record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Opsi Transaksi',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showEditDialog(context, record);
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.surfaceWhite,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _confirmArchive(context, record);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Hapus'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmArchive(BuildContext context, TransactionRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: const Text(
          'Transaksi ini dipindahkan ke Baru dihapus dan dikeluarkan dari '
          'semua perhitungan. Bisa dipulihkan kapan saja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final repo = context.read<BudgetRepository>();
              Navigator.pop(context);
              if (repo.archiveTransaction(record.id)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Transaksi dihapus'),
                    backgroundColor: AppColors.success,
                    // The undo lives here rather than in a separate screen,
                    // because the common case is a mis-tap seconds ago.
                    action: SnackBarAction(
                      label: 'Urungkan',
                      textColor: AppColors.surfaceWhite,
                      onPressed: () => repo.restoreTransaction(record.id),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.surfaceWhite,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, TransactionRecord shown) {
    // A row in a category-filtered list is a slice of the stored transaction,
    // not the transaction: applyLedgerFilter re-scales its amount to the
    // selected category's share and drops the other splits. Handing that slice
    // to updateTransaction would write the share back over the whole receipt —
    // a 120.000 share silently replacing the real 600.000. So resolve the stored
    // record by id first. The id survives the filter, which is what makes this
    // lookup possible.
    final original = context
        .read<BudgetRepository>()
        .activeHistory
        .firstWhere((r) => r.id == shown.id, orElse: () => shown);
    final record = original;

    final amountController = TextEditingController(text: record.totalAmount.toString());
    final merchantController = TextEditingController(text: record.merchantName);
    final itemsController = TextEditingController(text: record.items);
    String? selectedChargedTo = record.chargedTo;
    var selectedPaymentMethod = record.paymentMethod;
    DateTime editReceiptDate = DateTime.fromMillisecondsSinceEpoch(record.receiptDate);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit'),
          content: SingleChildScrollView(
            child: Consumer<BudgetRepository>(
              builder: (context, repo, _) {
                final isExpense = record.type == TransactionType.expense;
                final options = [allCategoriesLabel, ...repo.activeCategories.map((c) => c.name)];
                
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isExpense) ...[
                      TextField(
                        controller: merchantController,
                        decoration: const InputDecoration(
                          labelText: 'Merchant',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Income stores its note in the same column, so both
                    // record types get one editable free-text field.
                    TextField(
                      controller: itemsController,
                      decoration: InputDecoration(
                        labelText: isExpense ? 'Item' : 'Catatan',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PaymentMethodField(
                        value: selectedPaymentMethod,
                        onChanged: (v) =>
                            setDialogState(() => selectedPaymentMethod = v),
                      ),
                    ),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Nominal',
                        border: OutlineInputBorder(),
                        prefixText: 'Rp ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedChargedTo ?? options.first,
                      decoration: const InputDecoration(
                        labelText: 'Dibebankan ke',
                        border: OutlineInputBorder(),
                      ),
                      items: options.map((opt) {
                        return DropdownMenuItem(value: opt, child: Text(opt));
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedChargedTo = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: editReceiptDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => editReceiptDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Struk',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(DateFormat('dd MMM yyyy', 'id_ID').format(editReceiptDate)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  context.read<BudgetRepository>().updateTransaction(
                    transactionId: record.id,
                    newAmount: amount,
                    newMerchantName: merchantController.text,
                    newItems: itemsController.text,
                    newChargedTo: selectedChargedTo,
                    newReceiptDate: editReceiptDate.millisecondsSinceEpoch,
                    newPaymentMethod: selectedPaymentMethod,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaksi berhasil diupdate'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.surfaceWhite,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer2<BudgetRepository, LedgerFilterController>(
          builder: (context, repo, filters, _) {
            final filter = filters.filter;
            final all = repo.activeHistory;
            // Filtered here, against the selection Ringkasan published, rather
            // than in the repository — so the list and the total above it are
            // the same slice, and a filtered row can only ever be a view of a
            // stored record rather than a second source of truth.
            final history = applyLedgerFilter(all, filter);
            // The search narrows what the filter already narrowed, rather than
            // running alongside it — a search inside a filtered slice is what
            // the counter and the empty state have to describe, not two
            // independent lists that happen to be drawn from one.
            final query = _query.trim().toLowerCase();
            final results = query.isEmpty
                ? history
                : history
                    .where((record) => _matchesQuery(record, query))
                    .toList(growable: false);
            final searchActive = query.isNotEmpty;

            return CustomScrollView(
              slivers: [
                // Duolingo green hero header
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.green,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Riwayat',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                // Archived rows are the user's data but not
                                // their spending, so the count shows only what
                                // still counts and the archive is surfaced
                                // further down as its own section. Under a
                                // filter or a search it also has to say the
                                // list is narrowed — a bare count would read
                                // as the whole ledger while showing a slice
                                // of it.
                                filter.isActive || searchActive
                                    ? '${results.length} dari ${all.length} transaksi'
                                    : '${results.length} transaksi',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.history, color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  ),
                ),

                // The search sits closest to the header rather than below the filter
                // bar: the filter bar is conditional, the search is permanent,
                // and the one tool that is always there should be the one you
                // can find without looking for it.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        // An input, not a card: radius 8 like every other
                        // field in the app, so it reads as a tool rather
                        // than as a second table card stacked above the list.
                        borderRadius: BorderRadius.circular(8),
                        // Focus used to leave no trace here: the border sat in
                        // one color whether or not the cursor was in the field,
                        // so a tap that landed elsewhere looked identical to a
                        // tap that landed. Green is already the app's accent,
                        // so "active" needed no new color.
                        border: Border.all(
                          color: _searchFocus.hasFocus
                              ? AppColors.green
                              : AppColors.border,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.search,
                              size: 18, color: AppColors.textTertiary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocus,
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              textInputAction: TextInputAction.search,
                              // The theme draws its own 2px OutlineInputBorder
                              // for every state this field does not neutralize.
                              // Only `border` was set here, so the themed
                              // outline painted a second box inside this
                              // Container — rounder (12) than the outer (8).
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                filled: false,
                                hintText: 'Cari transaksi',
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          // The slot is this wide whether or not text exists.
                          // Tying the button's existence to having text made
                          // the row re-lay-out on the first character and on
                          // the last, so the hint slid sideways mid-tap — that
                          // reads as the field jumping rather than as something
                          // being cleared.
                          searchActive
                              ? GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  // Padding grows the hit area to 34x38 without
                                  // growing the glyph, so the × is a target
                                  // rather than a sliver.
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 10),
                                    child: Icon(Icons.close,
                                        size: 18,
                                        color: AppColors.textTertiary),
                                  ),
                                )
                              : const SizedBox(width: 34),
                        ],
                      ),
                    ),
                  ),
                ),

                // What the list is currently narrowed to. Without this the
                // header count alone leaves a filtered list looking like the
                // whole ledger, and a shared "Seluruhnya" row showing only part
                // of its amount would look like a wrong figure.
                if (filter.isActive)
                  SliverToBoxAdapter(
                    child: _ActiveFilterBar(
                      filter: filter,
                      onClear: () =>
                          context.read<LedgerFilterController>().clear(),
                    ),
                  ),

                // Empty state
                if (results.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.accentTint,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.receipt_long_outlined,
                              size: 36,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            // Three different situations, three different
                            // sentences. Telling someone with 76 transactions
                            // that they have none is worse than saying nothing,
                            // and so is blaming the filter when a search is
                            // what came up short.
                            searchActive
                                ? 'Tidak ada yang cocok dengan pencarian'
                                : filter.isActive
                                    ? 'Tidak ada transaksi di pilihan ini'
                                    : 'Belum ada transaksi',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                          if (searchActive || filter.isActive) ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () {
                                // Clear both. The two axes are independent, but
                                // leaving either one up would keep the list
                                // empty with no visible reason, and a clear
                                // button that only half-releases is a button
                                // you have to press twice.
                                _searchController.clear();
                                setState(() => _query = '');
                                context
                                    .read<LedgerFilterController>()
                                    .clear();
                              },
                              child: Text(
                                searchActive && filter.isActive
                                    ? 'Hapus pencarian & filter'
                                    : searchActive
                                        ? 'Bersihkan pencarian'
                                        : 'Hapus filter',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.green,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // Ledger-style transaction list
                if (results.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Column(
                          children: [
                            // Ledger header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                              child: Row(
                                children: [
                                  const SizedBox(width: 3),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Tanggal',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppColors.textTertiary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Deskripsi',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppColors.textTertiary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      'Nominal',
                                      textAlign: TextAlign.right,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppColors.textTertiary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Divider(color: AppColors.divider, height: 1),

                            // Transaction rows
                            ...results.asMap().entries.map((entry) {
                              final index = entry.key;
                              final record = entry.value;
                              final isExpense = record.type == TransactionType.expense;
                              // Group and label rows by when the money moved, the
                              // same basis Ringkasan sums on. Using the input
                              // timestamp here made a 30-Sep receipt keyed in on
                              // 1 Oct appear under October in one screen and
                              // September in the other.
                              final date = DateTime.fromMillisecondsSinceEpoch(
                                  effectiveDate(record));
                              final color = isExpense ? AppColors.expense : AppColors.income;

                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () => _showTransactionOptions(context, record),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                        // Type indicator bar
                                        Container(
                                          width: 3,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Date column
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                DateFormat('dd MMM', 'id_ID').format(date),
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                DateFormat('HH:mm', 'id_ID').format(date),
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                              // The row is now dated by the receipt, so when the two differ it is the keyed-in
                                              // date worth surfacing — that is the one the user may want to
                                              // double-check.
                                              if (record.receiptDate > 0 &&
                                                  record.receiptDate !=
                                                      record.timestamp)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    'Diinput ${DateFormat('dd MMM', 'id_ID').format(DateTime.fromMillisecondsSinceEpoch(record.timestamp))}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: AppColors
                                                              .textTertiary,
                                                          fontSize: 10,
                                                        ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // Description column
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (isExpense && record.merchantName.isNotEmpty)
                                                Text(
                                                  record.merchantName,
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              if (isExpense && record.items.isNotEmpty)
                                                Text(
                                                  record.items,
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              if (isExpense && record.chargedTo != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    record.chargedTo!,
                                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                      color: color,
                                                    ),
                                                  ),
                                                ),
                                              if (!isExpense)
                                                Text(
                                                  'Pemasukan',
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: color,
                                                  ),
                                                ),
                                              // Notes work for income too — same
                                              // column expenses use.
                                              if (!isExpense && record.items.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    record.items,
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              if (!isExpense &&
                                                  record.splits.isNotEmpty &&
                                                  // A category filter leaves one
                                                  // split on the row, so counting
                                                  // them would report the slice's
                                                  // shape while the amount above
                                                  // is the slice's size — telling
                                                  // the user about a transaction
                                                  // that does not look like this.
                                                  !filter.hasCategory)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    '${record.splits.length} alokasi',
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                  ),
                                                ),
                                              // Payment method, for both record
                                              // types — a muted last line so it
                                              // stays secondary to merchant /
                                              // notes / allocation.
                                              if (record.paymentMethod.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    record.paymentMethod,
                                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                      color: AppColors.textTertiary,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // Amount column - right aligned
                                        SizedBox(
                                          width: 100,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                isExpense ? '−' : '+',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: color,
                                                  height: 1.2,
                                                ),
                                              ),
                                              Text(
                                                'Rp ${_fmt(record.totalAmount)}',
                                                textAlign: TextAlign.right,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: color,
                                                  letterSpacing: -0.01,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (index < results.length - 1)
                                    Divider(color: AppColors.divider, height: 1),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// States the selection narrowing this list, and offers the way out of it.
///
/// The note about category shares is not decoration. Under a category filter a
/// shared "Seluruhnya" row shows only that category's part of the amount, which
/// is what makes the list add up to the Ringkasan total — but on its own it
/// reads as a wrong figure, so it is said out loud.
class _ActiveFilterBar extends StatelessWidget {
  const _ActiveFilterBar({required this.filter, required this.onClear});

  final LedgerFilter filter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.accentTint,
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined,
              size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filter.describe,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (filter.hasCategory) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Nominal mengikuti bagian ${filter.categoryLabel} saja.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
