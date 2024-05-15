import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module(
  "Unit | Route | discourse-ai-shared-conversation-show",
  function (hooks) {
    setupTest(hooks);

    test("it redirects based on currentUser preference", function (assert) {
      const transition = {
        intent: { url: "https://www.discourse.org" },
        abort() {
          assert.ok(true, "transition.abort() was called");
        },
      };

      const route = this.owner.lookup(
        "route:discourse-ai-shared-conversation-show"
      );

      const originalOpen = window.open;
      const originalRedirect = route.redirect;

      // Test when external_links_in_new_tab is true
      route.set("currentUser", {
        user_option: {
          external_links_in_new_tab: true,
        },
      });

      window.open = (url, target) => {
        assert.equal(
          url,
          "https://www.discourse.org",
          "window.open was called with the correct URL"
        );
        assert.equal(target, "_blank", 'window.open was called with "_blank"');
      };

      route.beforeModel(transition);

      // Test when external_links_in_new_tab is false
      route.set("currentUser", {
        user_option: {
          external_links_in_new_tab: false,
        },
      });

      route.redirect = (url) => {
        assert.equal(
          url,
          "https://www.discourse.org",
          "redirect was called with the correct URL"
        );
      };

      route.beforeModel(transition);

      // Reset
      window.open = originalOpen;
      route.redirect = originalRedirect;
    });
  }
);
