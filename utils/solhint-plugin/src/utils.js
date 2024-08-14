const constants = require("./constants");

function hasLeadingUnderscore(text) {
  return text && String(text).startsWith(constants.UNDERSCORE);
}

function hasTrailingUnderscore(text) {
  return text && String(text).endsWith(constants.UNDERSCORE);
}

module.exports = {
  hasLeadingUnderscore,
  hasTrailingUnderscore,
};
