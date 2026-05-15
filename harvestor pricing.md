\# 🚜 Implementation Guide: Multi-Configuration Equipment Pricing
 
\## 📖 Overview
 
This guide outlines the step-by-step process to support **multiple pricing configurations** (e.g., `2x2` and `4x4` modes for a Combined Harvester) within a **single booking entry**. The system will calculate line-item costs, aggregate them into a `total_cost`, and store the breakdown as JSON for auditability and reporting.
 
\---
 
\## 📦 Step 1: Database Schema Update
 
Add a `JSON` column to `chc_bookings` to store the service breakdown while keeping `total_cost` as the aggregated sum (ensures zero disruption to existing revenue reports).
 
**Run this SQL in your database:**
 
\`\`\`sql
 
ALTER TABLE chc\_bookings
 
ADD COLUMN service\_breakdown JSON DEFAULT NULL AFTER total\_cost;
 
\`\`\`
 
\---
 
\## 🔧 Step 2: Backend API (\`api (8).php\`)
 
Update the `completeBookingManual()` function to accept an array of service lines, calculate totals, and persist the breakdown.
 
\### 🔹 Replace the pricing & insertion logic inside `completeBookingManual($pdo)`:
 
\`\`\`php
 
// Inside completeBookingManual($pdo), after variable declarations:
 
$servicesJson = $input\['services'\] ?? null; // Expecting JSON string from Flutter app
 
$services = $servicesJson ? json\_decode($servicesJson, true) : null;
 
$totalAmount = 0.0;
 
$summaryUnit = $input\['unit\_type'\] ?? 'hour';
 
$summaryQty = 0.0;
 
if ($services && is\_array($services) && count($services) > 0) {
 
foreach ($services as $svc) {
 
$qty = floatval($svc\['qty'\] ?? 0);
 
$rate = floatval($svc\['rate'\] ?? 0);
 
$cost = $qty \* $rate;
 
$totalAmount += $cost;
 

$summaryQty += $qty;
 
}
 
$finalAmount = $totalAmount;
 
} else {
 
// Fallback to legacy single-service logic
 
$finalAmount = (float)($input\['final\_amount'\] ?? 0);
 
$summaryQty = (float)($input\['billed\_qty'\] ?? 0);
 
}
 
// ... \[Keep existing user/equipment lookup code unchanged\] ...
 
// UPDATE INSERT STATEMENT:
 
$stmtBook = $pdo->prepare("
 
INSERT INTO chc\_bookings (
 
booking\_id, user\_id, equipment\_type, billing\_type, crop\_type,
 
land\_size\_acres, billed\_qty, unit\_type, service\_date, rate,
 
total\_cost, service\_breakdown, notes, booking\_status, assignment\_status, assigned\_operator\_id,
 
operator\_notes, created\_at
 
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Completed', 'Completed', ?, ?, NOW())
 
");
 
$stmtBook->execute(\[
 
$bookingId, $farmerPhone, $equipment, $billingType, $cropType,
 
$landSizeAcres, $summaryQty, $summaryUnit, $serviceDate,
 
($totalAmount > 0 && $summaryQty > 0) ? ($totalAmount / $summaryQty) : $rate,
 
$finalAmount,
 
$services ? json\_encode($services) : null, // <-- NEW COLUMN
 
$notes, $operatorId, $operatorNotes
 
\]);
 
// UPDATE EXISTING BOOKING (if updating instead of inserting):
 
// Add `service_breakdown = ?` to the SET clause and bind:
 
// $services ? json\_encode($services) : null
 
\`\`\`
 
\---
 
\## Step 3: Flutter Operator App (\`textfile.txt\`)
 
Replace single quantity/rate inputs with a **dynamic multi-line service form**.
 
\### 3.1 Update State Variables
 
In `_ManualOrderSheetState`, replace single qty/rate controllers with:
 
\`\`\`dart
 
List<Map<String, dynamic>> \_services = \[
 
{'type': '2x2', 'qty': 0.0, 'rate': 0.0, 'unit': 'hour'}
 
\];
 
final List<TextEditingController> \_qtyControllers = \[TextEditingController()\];
 
final List<TextEditingController> \_rateControllers = \[TextEditingController()\];
 
\`\`\`
 
\### 🔹 3.2 Add Helper Methods
 
\`\`\`dart
 
void \_addServiceLine() {
 
setState(() {
 
\_services.add({'type': '4x4', 'qty': 0.0, 'rate': 0.0, 'unit': 'hour'});
 
\_qtyControllers.add(TextEditingController());
 
\_rateControllers.add(TextEditingController());
 
});
 
}
 
void \_removeServiceLine(int index) {
 
if (\_services.length <= 1) return;
 
setState(() {
 
\_services.removeAt(index);
 
\_qtyControllers.removeAt(index).dispose();
 
\_rateControllers.removeAt(index).dispose();
 
});
 
}
 
double get \_finalAmount {
 
double total = 0.0;
 
for (int i = 0; i < \_services.length; i++) {
 
final qty = double.tryParse(\_qtyControllers\[i\].text) ?? 0.0;
 
final rate = double.tryParse(\_rateControllers\[i\].text) ?? 0.0;
 
\_services\[i\]\['qty'\] = qty;
 
\_services\[i\]\['rate'\] = rate;
 
total += qty \* rate;
 
}
 
return total;
 
}
 
\`\`\`
 
\### 🔹 3.3 Replace `_buildStep2()` Usage Section
 
Find the `// Usage` section in `_buildStep2()` and replace it with:
 
\`\`\`dart
 
 *sectionTitle(Icons.speed* rounded, 'operator\_usage'.tr()),
 
const SizedBox(height: 16),
 
...List.generate(\_services.length, (index) {
 
return Container(
 
margin: const EdgeInsets.only(bottom: 12),
 
padding: const EdgeInsets.all(12),
 
decoration: BoxDecoration(
 
color: Colors.white, borderRadius: BorderRadius.circular(12),
 
border: Border.all(color: \_border),
 
),
 
child: Column(
 
crossAxisAlignment: CrossAxisAlignment.start,
 
children: \[
 
Row(
 
children: \[
 
DropdownButton<String>(
 
value: \_services\[index\]\['type'\],
 
isExpanded: true,
 
underline: const SizedBox(),
 
items: \['2x2', '4x4', 'Other'\].map((val) =>
 
DropdownMenuItem(value: val, child: Text(val))
 
).toList(),
 
onChanged: (val) => setState(() => \_services\[index\]\['type'\] = val),
 
),
 
if (index > 0)
 
IconButton(
 
icon: const Icon(Icons.delete\_outline, color: Colors.redAccent, size: 20),
 
onPressed: () => \_removeServiceLine(index),
 
),
 
\],
 
),
 
const SizedBox(height: 8),
 
Row(
 
children: \[
 
Expanded(
 
child: TextField(
 
controller: \_qtyControllers\[index\],
 
keyboardType: const TextInputType.numberWithOptions(decimal: true),
 
decoration: InputDecoration(
 
hintText: 'Qty / Hours',
 
suffixText:  *isTimeBased ? 'hrs' : (* isTractorTrolley ? 'trips' : ''),
 
contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
 
),
 
onChanged: (\_) => setState(() {}),
 
),
 
),
 
const SizedBox(width: 8),
 
Expanded(
 
child: TextField(
 
controller: \_rateControllers\[index\],
 
keyboardType: const TextInputType.numberWithOptions(decimal: true),
 
decoration: InputDecoration(
 
hintText: 'Rate',
 
prefixText: '₹',
 
contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 
border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
 
),
 
onChanged: (\_) => setState(() {}),
 
),
 
),
 
\],
 
),
 
if (index == \_services.length - 1)
 
Align(
 
alignment: Alignment.centerRight,
 
child: TextButton.icon(
 
onPressed: \_addServiceLine,
 
icon: const Icon(Icons.add, size: 18),
 
label: const Text('Add Service Line'),
 
style: TextButton.styleFrom(foregroundColor: \_accent, padding: [EdgeInsets.zero](http://EdgeInsets.zero) ),
 
),
 
),
 
\],
 
),
 
);
 
}),
 
\`\`\`
 
\### 🔹 3.4 Update Receipt (\`\_buildStep3()\`)
 
Replace the single rate/qty display with an itemized list:
 
\`\`\`dart
 
// Inside \_buildStep3() Container, replace the middle receipt rows with:
 
...\_services.asMap().[entries.map](http://entries.map) ((entry) {
 
final i = entry.key;
 
final svc = entry.value;
 
final lineCost = (svc\['qty'\] ?? 0) \* (svc\['rate'\] ?? 0);
 
return \_receiptRow(
 
'${svc\['type'\] ?? 'Service'} ${i+1}',
 
'${svc\['qty'\]} × ₹${svc\['rate'\]} = ₹${lineCost.toStringAsFixed(0)}'
 
);
 
}).toList(),
 
const Divider(height: 32, color: \_border),
 
 *receiptRow('operator* total\_bill'.tr(), '${\_finalAmount.toStringAsFixed(0)}', isTotal: true),
 
\`\`\`
 
\### 🔹 3.5 Update `_submit()` Payload
 
Replace the `ApiService.completeBookingManual` call with:
 
\`\`\`dart
 
// Add at top of file: import 'dart:convert';
 
final res = await ApiService.completeBookingManual(
 
operatorId: widget.operator.operatorId,
 
bookingId: widget.prefillBooking?\['booking\_id'\]?.toString(),
 
farmerPhone: \_phoneController.text.trim(),
 
farmerName: \_nameController.text.trim(),
 
village: \_villageController.text.trim(),
 
equipmentUsed:  *selectedEquipment!\['name* en'\] ?? 'Equipment',
 
equipmentId: \_selectedEquipment!\['id'\],
 
startTime: '00:00',
 
endTime: '00:00',
 
distance:  *isTractorTrolley ?*  distance : 0,
 
serviceDate: '${\_serviceDate!.year}-${\_serviceDate!.month}-${\_serviceDate!.day}',
 
cropType:  *cropController.text.isNotEmpty ?*  cropController.text : null,
 
landSizeAcres: double.tryParse(\_landSizeController.text) ?? 0,
 
services: jsonEncode(\_services), // <-- Sends breakdown as JSON string
 
billedQty: \_services.fold(0.0, (sum, s) => sum + (s\['qty'\] ?? 0)),
 
unitType:  *isTimeBased ? 'hour' : (* isTractorTrolley ? 'trip' : 'unit'),
 
rate: 0.0, // Calculated on backend
 
finalAmount: \_finalAmount,
 
);
 
\`\`\`
 
\---
 
\## 📊 Step 4: Dashboard & Reporting (\`chc\_dashboard (1).php\`)
 
\- ✅ **Backward Compatibility:** All existing KPIs, charts, and exports continue to work since `total_cost` is preserved.
 
\- **Future Enhancement:** In the order details modal (\`get\_task\_details\` AJAX action), fetch `service_breakdown`, parse it in JS, and render a mini-table:
 
\`\`\`javascript
 
const breakdown = JSON.parse(taskData.service\_breakdown || '\[\]');
 
breakdown.forEach(item => {
 
// Render: Type | Qty | Rate | Line Cost
 
});
 
\`\`\`
 
\---
 
\## ✅ Step 5: Pre-Launch Checklist
 
\- \[ \] Run `ALTER TABLE` query on production database.
 
\- \[ \] Backup `api (8).php` and `textfile.txt` before applying changes.
 
\- \[ \] Clear Flutter cache: `flutter clean && flutter pub get`.
 
\- \[ \] Test **single service line** (backward compatibility).
 
\- \[ \] Test **two service lines** (e.g., `2x2` + `4x4`) → verify `total_cost` matches sum & `service_breakdown` JSON is stored.
 
\- \[ \] Verify dashboard revenue totals remain accurate.
 
\- \[ \] Validate form prevents submission if `qty` or `rate` is missing/zero.
 
\---
 
\## 💡 Pro Tips & Next Steps
 
1\. **Input Validation:** Add real-time error banners if `qty <= 0` or `rate <= 0`.
 
2\. **Auto-Focus:** Use `FocusNode` to auto-advance between qty/rate fields.
 
3\. **Phone Formatting:** Integrate `intl_phone_field` for consistent number input.
 
4\. **Dark Mode:** Wrap colors in `Theme.of(context).brightness == Brightness.dark` conditionals.
 
5\. **API Versioning:** Consider adding `?v=2` to `completeBookingManual` to safely rollback if needed.
 
\> 📁 **Save this as:** `MULTI_CONFIG_PRICING_GUIDE.md`
 
\> 🔧 **Need the AlpineJS/JS snippet to render the breakdown in the dashboard modal?** Reply with `"dashboard modal code"` and I'll generate it instantly.