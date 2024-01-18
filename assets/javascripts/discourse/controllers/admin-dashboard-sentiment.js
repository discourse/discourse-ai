import { computed } from "@ember/object";
import AdminDashboardTabController from "admin/controllers/admin-dashboard-tab";

export default class AdminDashboardSentiment extends AdminDashboardTabController {
  @computed("startDate", "endDate")
  get filters() {
    return { startDate: this.startDate, endDate: this.endDate };
  }
}
