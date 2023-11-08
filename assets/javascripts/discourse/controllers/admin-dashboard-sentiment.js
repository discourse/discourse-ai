import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import getURL from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";
import CustomDateRangeModal from "admin/components/modal/custom-date-range";
import PeriodComputationMixin from "admin/mixins/period-computation";

export default class AdminDashboardSentiment extends Controller.extend(
  PeriodComputationMixin
) {
  @service modal;

  @discourseComputed("startDate", "endDate")
  filters(startDate, endDate) {
    return { startDate, endDate };
  }

  _reportsForPeriodURL(period) {
    return getURL(`/admin/dashboard/sentiment?period=${period}`);
  }

  @action
  setCustomDateRange(startDate, endDate) {
    this.setProperties({ startDate, endDate });
  }

  @action
  openCustomDateRangeModal() {
    this.modal.show(CustomDateRangeModal, {
      model: {
        startDate: this.startDate,
        endDate: this.endDate,
        setCustomDateRange: this.setCustomDateRange,
      },
    });
  }
}
