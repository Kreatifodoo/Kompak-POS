import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/enums.dart';

final paymentMethodProvider = StateProvider<PaymentMethod>((ref) => PaymentMethod.cash);

final cashTenderedProvider = StateProvider<double>((ref) => 0);
