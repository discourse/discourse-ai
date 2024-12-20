import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getOwner } from "discourse-common/lib/get-owner";

const FILTERS = {
  category: "category:",
  tags: "tags:",
  "created by": "created-by:",
  "status archived": "status:archived",
  "status closed": "status:closed",
  "status deleted": "status:deleted",
  "status listed": "status:listed",
  "status open": "status:open",
  "status public": "status:public",
  "status unlisted": "status:unlisted",
  "in bookmarked": "in:bookmarked",
  "in muted": "in:muted",
  "in normal": "in:normal",
  "in pinned": "in:pinned",
  "in tracking": "in:tracking",
  "in watching": "in:watching",
  "activity before": "activity-before:",
  "activity after": "activity-after:",
  "created before": "created-before:",
  "created after": "created-after:",
  "latest post before": "latest-post-before:",
  "latest post after": "latest-post-after:",
  "minimum likes": "likes-min:",
  "maximum likes": "likes-max:",
  "minimum likes by original poster": "likes-op-min:",
  "maximum likes by original poster": "likes-op-max:",
  "minimum posts": "posts-min:",
  "maximum posts": "posts-max:",
  "minimum posters": "posters-min:",
  "maximum posters": "posters-max:",
  "minimum views": "views-min:",
  "maximum views": "views-max:",
  "sort by activity": "order:activity",
  "sort by category": "order:category",
  "sort by created date": "order:created",
  "sort by latest post": "order:latest-post",
  "sort by likes": "order:likes",
  "sort by likes (original poster)": "order:likes-op",
  "sort by posters": "order:posters",
  "sort by views": "order:views",
};

function constructQueryString(aiFilters) {
  return aiFilters
    .flatMap((filterLine) => {
      // Split on spaces to get individual "key:value" segments
      return filterLine.split(" ").filter((segment) => segment.includes(":"));
    })
    .map((filterSegment) => {
      const [key, ...valueParts] = filterSegment.split(":");
      const value = valueParts.join(":").trim();

      const validKey = Object.keys(FILTERS).find(
        (filterKey) => filterKey.toLowerCase() === key.toLowerCase()
      );

      if (validKey) {
        return `${FILTERS[validKey]}${value}`;
      }

      // If the segment already starts with a known prefix
      if (
        Object.values(FILTERS).some((filterValue) =>
          filterSegment.startsWith(filterValue)
        )
      ) {
        return filterSegment.trim();
      }

      // Otherwise, it's invalid
      return null;
    })
    .filter(Boolean)
    .join(" ");
}

export default class AiFilterInput extends Component {
  @service site;

  @tracked userInput = "";
  @tracked loading = false;
  @tracked error = null;

  siteCategories = [
    "gaming",
    "support",
    "general",
    "announcements",
    "off-topic",
  ];

  get discoveryFilter() {
    return getOwner(this).lookup("controller:discovery/filter");
  }

  @action
  handleInputChange(event) {
    this.userInput = event.target.value;
  }

  @action
  handleKeydown(event) {
    if (event.key === "Enter") {
      this.submitQuery();
    }
  }

  @action
  async submitQuery() {
    if (!this.userInput.trim()) {
      this.error = "Please enter a query.";
      return;
    }

    this.loading = true;
    this.error = null;

    try {
      const categoriesListStr = this.site.categories
        .map((cat) => cat.name)
        .join(", ");
      const now = new Date();
      const currentYear = now.getFullYear();
      const currentMonth = String(now.getMonth() + 1).padStart(2, "0");
      const currentDay = String(now.getDate()).padStart(2, "0");
      const currentDateStr = `${currentYear}-${currentMonth}-${currentDay}`;

      const response = await ajax("/discourse-ai/ai-helper/suggest", {
        method: "POST",
        data: {
          text: this.userInput,
          mode: -305,
          custom_prompt: `
      The following are valid categories on this site: ${categoriesListStr}.
      The current date (in the user's time) is: ${currentDateStr}.

      If the user references dates, convert them to YYYY-MM-DD.
      If the user says "0 replies," that means posts-max:1.
      Map ambiguous categories to the closest match.

      Return filters as a clean, space-separated string without quotes.
      Do not add extra quotes around filters.
    `,
        },
      });

      let aiSuggestions = response.suggestions || "";
      aiSuggestions = aiSuggestions.replace(/"/g, ""); // remove all quotes

      //  turn it into an array with one element
      const aiFilters = aiSuggestions ? [aiSuggestions] : [];

      let queryString = constructQueryString(aiFilters);

      // remove quotes
      queryString = queryString.replace(/"/g, "");

      this.args.updateQueryString(queryString);
      this.discoveryFilter.updateTopicsListQueryParams(queryString);

      this.aiTitle = aiTitle;
      this.aiExplanation = aiExplanation;

      document.getElementById("queryStringInput").focus();
    } catch (error) {
      popupAjaxError(error);
      this.error = "Failed to process the query. Please try again.";
    } finally {
      this.loading = false;
    }
  }

  <template>
    <div class="ai-filter-input">
      {{#if this.aiTitle}}
        <h2>{{this.aiTitle}}</h2>
      {{/if}}

      {{#if this.aiExplanation}}
        <p class="explanation">{{this.aiExplanation}}</p>
      {{/if}}

      <input
        type="text"
        id="aiQueryStringInput"
        placeholder="Enter your query..."
        value={{this.userInput}}
        {{on "input" this.handleInputChange}}
        {{on "keydown" this.handleKeydown}}
      />

      {{if this.loading "Processing..."}}

      {{#if this.error}}
        <p class="error">{{this.error}}</p>
      {{/if}}
    </div>
  </template>
}
