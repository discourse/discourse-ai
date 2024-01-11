import { module, test } from "qunit";
import { addProgressDot } from "discourse/plugins/discourse-ai/discourse/lib/ai-streamer";

module("Discourse AI | Unit | Lib | ai-streamer", function () {
  function confirmPlaceholder(html, expected, assert) {
    const element = document.createElement("div");
    element.innerHTML = html;

    const expectedElement = document.createElement("div");
    expectedElement.innerHTML = expected;

    addProgressDot(element);

    assert.equal(element.innerHTML, expectedElement.innerHTML);
  }

  test("inserts progress span in correct location for simple div", function (assert) {
    const html = "<div>hello world<div>hello 2</div></div>";
    const expected =
      "<div>hello world<div>hello 2<span class='progress-dot'></span></div></div>";

    confirmPlaceholder(html, expected, assert);
  });

  test("inserts progress span in correct location for lists", function (assert) {
    const html = "<p>test</p><ul><li>hello world</li><li>hello world</li></ul>";
    const expected =
      "<p>test</p><ul><li>hello world</li><li>hello world<span class='progress-dot'></span></li></ul>";

    confirmPlaceholder(html, expected, assert);
  });

  test("inserts correctly if list has blank html nodes", function (assert) {
    const html = `<ul>
<li><strong>Bold Text</strong>: To</li>

</ul>`;

    const expected = `<ul>
<li><strong>Bold Text</strong>: To<span class="progress-dot"></span></li>

</ul>`;

    confirmPlaceholder(html, expected, assert);
  });

  test("inserts correctly for tables", function (assert) {
    const html = `<table>
<tbody>
<tr>
<td>Bananas</td>
<td>20</td>
<td>$0.50</td>
</tr>
</tbody>
</table>
`;

    const expected = `<table>
<tbody>
<tr>
<td>Bananas</td>
<td>20</td>
<td>$0.50<span class="progress-dot"></span></td>
</tr>
</tbody>
</table>
`;

    confirmPlaceholder(html, expected, assert);
  });
});
