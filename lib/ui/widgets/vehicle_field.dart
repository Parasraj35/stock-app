import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/vehicles.dart';
import '../theme/tokens.dart';

/// The Debit/Credit form's VEHICLE NO. field. Tapping it lists the saved
/// vehicles (with the CFT each carries); typing narrows the list. Required.
class VehicleField extends StatelessWidget {
  const VehicleField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.vehicles,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<Vehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Vehicle>(
      textEditingController: controller,
      focusNode: focusNode,
      // An empty field offers every vehicle, so it works as a picker.
      optionsBuilder: (v) {
        final q = v.text.trim().toUpperCase();
        return vehicles.where((x) => x.vehicleNo.toUpperCase().contains(q));
      },
      displayStringForOption: (x) => x.vehicleNo,
      onSelected: (x) => controller.text = x.vehicleNo,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'VEHICLE NO.',
            suffixIcon: vehicles.isEmpty
                ? null
                : const Icon(Icons.arrow_drop_down),
          ),
          validator: (v) => normalizeVehicleNo(v) == null ? 'Required' : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 260),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final x = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    title: Text(x.vehicleNo),
                    trailing: Text(
                      '${formatDecimal(x.cft)} CFT',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onTap: () => onSelected(x),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
