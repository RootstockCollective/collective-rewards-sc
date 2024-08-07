function hasLeadingUnderscore(text) {
  return text && text[0] === "_";
}

function hasTrailingUnderscore(text) {
  return text && text[text.length - 1] === "_";
}

module.exports = {
  hasLeadingUnderscore,
  hasTrailingUnderscore,
};
