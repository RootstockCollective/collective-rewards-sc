const constants = require("./constants");

function startsWithUnderscore(text) {
  return text && text[0] === constants.UNDERSCORE;
}

function endsWithUnderscore(text) {
  return text && text[text.length - 1] === constants.UNDERSCORE;
}

module.exports = {
  startsWithUnderscore,
  endsWithUnderscore,
};
