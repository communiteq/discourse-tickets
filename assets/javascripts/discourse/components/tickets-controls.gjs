import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import ComboBox from "select-kit/components/combo-box";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { isTicketTag, generateSelectKitContent } from "../lib/ticket-utilities";
import { fn, hash } from "@ember/helper";
import i18n from "discourse/helpers/i18n";
import I18n from "discourse-i18n";

const TICKET_TYPES = ["priority", "status", "reason"];

export default class TicketsControls extends Component {
  @service site;
  @service siteSettings;
  @service taskActions;

  @tracked includeUsernames = [];
  @tracked hasGroups = false;

  constructor(owner, args) {
    super(owner, args);
    if (this.topic.get("archetype") === "private_message") {
      let includeGroup = this.siteSettings.tickets_include_group;
      const currentGroups = this.topic.get("content.details.allowed_groups");

      if (currentGroups && currentGroups.length) {
        let names = currentGroups.map((cg) => cg.name);
        if (names.indexOf(includeGroup) > -1) {
          includeGroup = null;
        }
      }

      if (includeGroup) {
        this.includeUsernames = [includeGroup];
        this.hasGroups = true;
        this.includedChanged();
      }
    }
  }

  get topic() {
    return this.args.topic;
  }

  get ticketTags() {
    return this.site.get("ticket_tags");
  }

  get currentTags() {
    return this.topic.get("tags") || [];
  }

  get toggleClasses() {
    let classes = "toggle-ticket";
    if (this.topic.get("is_ticket")) {
      classes += " btn-primary";
    }
    return classes;
  }

  get showInclude() {
    return this.topic.get("archetype") === "private_message";
  }

  get priorityList() {
    return generateSelectKitContent(this.ticketTags.priority);
  }

  get statusList() {
    return generateSelectKitContent(this.ticketTags.status);
  }

  get reasonList() {
    return generateSelectKitContent(this.ticketTags.reason);
  }

  get priority() {
    return this.findCurrentTag(this.ticketTags.priority);
  }

  get status() {
    return this.findCurrentTag(this.ticketTags.status);
  }

  get reason() {
    return this.findCurrentTag(this.ticketTags.reason);
  }

  get priorityNone() {
    return { name: I18n.t("tickets.topic.select", { type: "priority" }) };
  }

  get statusNone() {
    return { name: I18n.t("tickets.topic.select", { type: "status" }) };
  }

  get reasonNone() {
    return { name: I18n.t("tickets.topic.select", { type: "reason" }) };
  }

  findCurrentTag(list) {
    if (list && this.currentTags) {
      return this.currentTags.find((t) => list.indexOf(t) > -1);
    }
    return "";
  }

  @action
  toggleIsTicket() {
    this.topic.toggleProperty("is_ticket");
    // Since Ember 3.1, this is usually fine as you no longer need to use `.get()`
    // to access computed properties. However, in this case, the object in question
    // is a special kind of Ember object (a proxy). Therefore, it is still necessary
    // to use `.get('is_ticket')` in this case.
    if (this.topic.get("is_ticket")) {
      this.addTickets();
    } else {
      this.removeTickets();
    }
  }

  @action
  updateTicket(ticketType, value) {
    const list = this.ticketTags[ticketType];
    let tags = [...(this.topic.get("tags") || [])];

    // Remove existing tags of this type
    if (list) {
      tags = tags.filter((t) => list.indexOf(t) === -1);
    }

    // Add new value if present
    if (value) {
      tags.push(value);
    }

    this.topic.set("tags", tags);
  }

  @action
  addTickets() {
    TICKET_TYPES.forEach((type) => {
      this.updateTicket(type, this[type]);
    });
  }

  @action
  removeTickets() {
    let tags = this.topic.tags;
    if (tags) {
      tags = tags.filter((t) => !isTicketTag(t));
      this.topic.set("tags", tags);
    }
  }

  @action
  updateIncludeUsernames(selected, content) {
    if (!content?.length) {
      this.includeUsernames = [];
      this.hasGroups = false;
    } else {
      this.includeUsernames = selected;
      this.hasGroups = content[0].isGroup || false;
    }
    this.includedChanged();
  }

  includedChanged() {
    const type = this.hasGroups ? "groups" : "users";
    this.topic.set(`allowed_${type}`, this.includeUsernames.join(","));
  }

  @action
  unassign() {
    this.taskActions.unassign(this.topic.id, "Topic");
  }

  @action
  assign() {
    this.taskActions.assign(this.topic);
  }

  <template>
    <DButton
      @label="tickets.topic.is_ticket"
      @icon={{this.siteSettings.tickets_icon}}
      @action={{this.toggleIsTicket}}
      class={{this.toggleClasses}}
    />

    {{#if this.topic.is_ticket}}
      <div class="ticket-controls">
        <div class="control-group">
          <label>{{i18n "tickets.priority"}}</label>
          <div class="controls">
            <ComboBox
              @content={{this.priorityList}}
              @value={{this.priority}}
              @none={{this.priorityNone}}
              @onChange={{fn this.updateTicket "priority"}}
            />
          </div>
        </div>

        <div class="control-group">
          <label>{{i18n "tickets.status"}}</label>
          <div class="controls">
            <ComboBox
              @content={{this.statusList}}
              @value={{this.status}}
              @none={{this.statusNone}}
              @onChange={{fn this.updateTicket "status"}}
            />
          </div>
        </div>

        <div class="control-group">
          <label>{{i18n "tickets.reason"}}</label>
          <div class="controls">
            <ComboBox
              @content={{this.reasonList}}
              @value={{this.reason}}
              @none={{this.reasonNone}}
              @onChange={{fn this.updateTicket "reason"}}
            />
          </div>
        </div>

        {{#if this.showInclude}}
          <div class="control-group">
            <label>{{i18n "tickets.include"}}</label>
            <div class="controls">
              <EmailGroupUserChooser
                @value={{this.includeUsernames}}
                @onChange={{this.updateIncludeUsernames}}
                @options={{hash
                  maximum=1
                  excludeCurrentUser=true
                  includeMessageableGroups=true
                  filterPlaceholder="tickets.include_placeholder"
                }}
              />
            </div>
          </div>
        {{/if}}
      </div>

      {{#if this.siteSettings.assign_enabled}}
        {{#if this.topic.assigned_to_user.username}}
          <DButton
            class="assign"
            @icon="user-xmark"
            @action={{this.unassign}}
            @label="discourse_assign.unassign.title"
            @title="discourse_assign.unassign.help"
          />
        {{else}}
          <DButton
            class="assign"
            @icon="user-plus"
            @action={{this.assign}}
            @label="discourse_assign.assign.title"
            @title="discourse_assign.assign.help"
          />
        {{/if}}
      {{/if}}
    {{/if}}
  </template>
}
