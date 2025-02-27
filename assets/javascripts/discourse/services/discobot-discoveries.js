import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

export default class DiscobotDiscoveries extends Service {
  // We use this to retain state after search menu gets closed.
  // Similar to discourse/discourse#25504
  @tracked discovery = "";
  @tracked lastQuery = "";
  @tracked discoveryTimedOut = false;
  @tracked modelUsed = "";

  resetDiscovery() {
    this.discovery = "";
    this.discoveryTimedOut = false;
    this.modelUsed = "";
  }
}
