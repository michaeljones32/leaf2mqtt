import 'package:dartnissanconnect/dartnissanconnect.dart';
import 'package:dartnissanconnect/src/nissanconnect_hvac.dart';

import 'builder/leaf_battery_builder.dart';
import 'builder/leaf_climate_builder.dart';
import 'leaf_session.dart';
import 'leaf_vehicle.dart';

class NissanConnectSessionWrapper extends LeafSessionInternal {
  NissanConnectSessionWrapper(String username, String password)
    : super(username, password);

  NissanConnectSession _session;

  @override
  Future<void> login() async {
    _session = NissanConnectSession();
    await _session.login(username: username, password: password);

    final List<VehicleInternal> newVvehicles = _session.vehicles.map((NissanConnectVehicle vehicle) =>
      NissanConnectVehicleWrapper(vehicle)).toList();

    setVehicles(newVvehicles);
  }
}

class NissanConnectVehicleWrapper extends VehicleInternal {
  NissanConnectVehicleWrapper(NissanConnectVehicle vehicle) :
    _session = vehicle.session,
    super(vehicle.nickname.toString(), vehicle.vin.toString());

  final NissanConnectSession _session;

  NissanConnectVehicle _getVehicle() =>
    _session.vehicles.firstWhere((NissanConnectVehicle v) => v.vin.toString() == vin,
      orElse: () => throw Exception('Could not find matching vehicle: $vin number of vehicles: ${_session.vehicles.length}'));

  @override
  bool isFirstVehicle() => _session.vehicle.vin == vin;

  @override
  Future<Map<String, String>> fetchBatteryStatus() async {
    final NissanConnectBattery battery = await _getVehicle().requestBatteryStatus();

    final int percentage =
      double.tryParse(battery.batteryPercentage.replaceFirst('%', ''))?.round();

    return saveAndPrependVin(BatteryInfoBuilder()
           .withChargePercentage(percentage ?? -1)
           .withConnectedStatus(battery.isConnected)
           .withChargingStatus(battery.isCharging)
           .withCruisingRangeAcOffKm(battery.cruisingRangeAcOffKm)
           .withCruisingRangeAcOffMiles(battery.cruisingRangeAcOffMiles)
           .withCruisingRangeAcOnKm(battery.cruisingRangeAcOnKm)
           .withCruisingRangeAcOnMiles(battery.cruisingRangeAcOnMiles)
           .withLastUpdatedDateTime(battery.dateTime)
           .withTimeToFullL2(battery.timeToFullNormal)
           .withTimeToFullL2_6kw(battery.timeToFullFast)
           .withTimeToFullTrickle(battery.timeToFullSlow)
           .withChargingSpeed(battery.chargingSpeed.toString())
           .build());
  }

  @override
  Future<bool> startCharging() =>
    _getVehicle().requestChargingStart();

  @override
  Future<Map<String, String>> fetchClimateStatus() async {
    final NissanConnectVehicle vehicle = _getVehicle();

    await vehicle.requestClimateControlStatusRefresh();
    final NissanConnectHVAC hvac = await vehicle.requestClimateControlStatus();

    return saveAndPrependVin(ClimateInfoBuilder()
            .withCabinTemperatureCelsius(hvac.cabinTemperature)
            .withHvacRunningStatus(hvac.isRunning)
            .build());
  }

  @override
  Future<bool> startClimate(int targetTemperatureCelsius) =>
    _getVehicle().requestClimateControlOn(
      DateTime.now().add(const Duration(seconds: 5)),
      targetTemperatureCelsius);

  @override
  Future<bool> stopClimate() =>
    _getVehicle().requestClimateControlOff();
}
