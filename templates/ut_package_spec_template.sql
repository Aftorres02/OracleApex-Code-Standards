-- Implements: .claude/rules/testing.md (suite naming, structure, isolation)
create or replace package ut_prefix_<area>
as
-- =============================================================================
-- Package: ut_prefix_<area>
-- Purpose: utPLSQL suite for prefix_<module>_api — <aspect under test>.
--
-- @author  <Author Name> (<Role>)
-- @created <Month DD, YYYY>
-- @issue   <TICKET>
-- =============================================================================

  --%suite(prefix_<module>_api: <aspect under test>)
  --%suitepath(prefix.<area>)

  -- Default: utPLSQL rolls back every test, so fixtures and setting changes
  -- disappear on their own. Only when the code under test commits
  -- (autonomous transaction, explicit commit, logger.set_pref ...) can that
  -- rollback not undo it: then remove the leading "-- " below and uncomment
  -- the commit at the end of cleanup_fixtures and restore_original_settings.
  -- --%rollback(manual)

  --%beforeall
  procedure save_original_settings;

  --%afterall
  procedure restore_original_settings;

  --%beforeeach
  procedure seed_fixtures;

  --%aftereach
  procedure cleanup_fixtures;


  --%test(<Expected behavior, written as a sentence>)
  procedure <expected_behavior>;


  --%test(<Raises -20001 when the input is ...>)
  --%throws(-20001)
  procedure <raises_when_condition>;


  --%test(<What the fix guarantees>, <TICKET>)
  procedure <regression_ticket_behavior>;

end ut_prefix_<area>;
/
