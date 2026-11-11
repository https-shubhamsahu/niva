/// The Sakshi beam saw the standing foot step off. [deviceMs] is the beam
/// hub's own clock; [phoneMs] is the same instant on the phone clock.
class TimedBeamEvent {
  final int deviceMs;
  final int phoneMs;

  const TimedBeamEvent({required this.deviceMs, required this.phoneMs});
}
