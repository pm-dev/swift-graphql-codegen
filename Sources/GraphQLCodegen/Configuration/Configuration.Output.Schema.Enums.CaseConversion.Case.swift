extension Configuration.Output.Schema.Enums.CaseConversion {
    public enum Case: Sendable {
        case lowerCamel // thisIsCamelCase
        case macro // THIS_IS_MACRO_CASE
    }
}
