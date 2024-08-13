class Base {
  constructor(reporter, ruleId) {
    this.reporter = reporter;
    this.ruleId = ruleId;
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
