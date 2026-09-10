enum SongDestinationType { setlist, schedule }

class SongDestination {
  const SongDestination.setlist(this.id) : type = SongDestinationType.setlist;
  const SongDestination.schedule(this.id) : type = SongDestinationType.schedule;

  final String id;
  final SongDestinationType type;
  bool get isSchedule => type == SongDestinationType.schedule;
}
