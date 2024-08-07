class Base {
  constructor(reporter, config) {
    this.reporter = reporter;
    this.ruleId = this.constructor.ruleId;
    if (this.ruleId === undefined) {
      throw Error("missing ruleId static property");
    }
    this.config = config;
  }

  error(ctx, message) {
    this.addReport("error", ctx, message);
  }

  warn(ctx, message) {
    this.addReport("warn", ctx, message);
  }

  addReport(type, ctx, message) {
    this.reporter[type](ctx, this.ruleId, message);
  }
}

module.exports = Base;
