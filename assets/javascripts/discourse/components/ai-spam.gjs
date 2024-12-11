import Component from "@glimmer/component";

export default class AiSpam extends Component {
  get tbd() {
    return "To be done";
  }

  <template>
    {{this.tbd}}
  </template>
}
