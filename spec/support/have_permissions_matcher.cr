module Spectator::Matchers
  struct HavePermissionsMatcher(ExpectedType) < Spectator::Matchers::ValueMatcher(ExpectedType)
    def description : String
      "have permissions of #{expected.label}"
    end

    # Checks whether the matcher is satisfied with the expression given to it.
    private def match?(actual : Spectator::TestExpression(T)) : Bool forall T
      File.info(actual.value).permissions.value == expected.value
    end

    private def failure_message(actual : Spectator::TestExpression(T)) : String forall T
      "#{actual.label} does not have permissions of #{expected.label}"
    end

    private def failure_message_when_negated(actual : Spectator::TestExpression(T)) : String
      "#{actual.label} should not have permissions of #{expected.label}"
    end
  end
end

macro have_permissions(expected)
  %test_value = ::Spectator::TestValue.new({{expected}}, {{expected.stringify}})
  ::Spectator::Matchers::HavePermissionsMatcher.new(%test_value)
end
