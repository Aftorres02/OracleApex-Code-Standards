-- Implements: .claude/rules/testing.md (fixtures, isolation, assertions)
create or replace package body ut_prefix_<area>
as

  -- Every row this suite creates carries this marker, so cleanup_fixtures
  -- removes exactly what the suite created and nothing else.
  gc_marker constant varchar2(30 char) := 'UT_PREFIX_<AREA>:';

  g_original_setting prefix_<settings_table>.<value_column>%type;








  -- ===========================================================================
  -- PROCEDURE: save_original_settings (%beforeall)
  -- ===========================================================================
  -- Delete this pair (and its spec lines) if the suite changes no settings.
  procedure save_original_settings
  is
  begin
    select s.<value_column>
      into g_original_setting
      from prefix_<settings_table> s
     where s.<name_column> = '<SETTING_NAME>';
  end save_original_settings;








  -- ===========================================================================
  -- PROCEDURE: restore_original_settings (%afterall)
  -- ===========================================================================
  procedure restore_original_settings
  is
  begin
    update prefix_<settings_table> s
       set s.<value_column> = g_original_setting
     where s.<name_column> = '<SETTING_NAME>';

    -- --%rollback(manual) suites only: uncomment. In the default automatic
    -- mode a commit here ends utPLSQL's savepoint and leaks test data.
    -- commit;
  end restore_original_settings;








  -- ===========================================================================
  -- PROCEDURE: seed_fixtures (%beforeeach)
  -- ===========================================================================
  procedure seed_fixtures
  is
  begin
    insert
      into prefix_<table_name> (
           <column_1>
         , active_yn
    )
    values (
           gc_marker || ' active row'
         , 'Y'
    );
  end seed_fixtures;








  -- ===========================================================================
  -- PROCEDURE: cleanup_fixtures (%aftereach)
  -- ===========================================================================
  -- Required with --%rollback(manual). In the default automatic mode
  -- utPLSQL already undoes the fixtures; this delete is then redundant but
  -- harmless as long as it does not commit.
  procedure cleanup_fixtures
  is
  begin
    delete
      from prefix_<table_name> t
     where t.<column_1> like gc_marker || '%';

    -- --%rollback(manual) suites only: uncomment.
    -- commit;
  end cleanup_fixtures;








  -- ===========================================================================
  -- TEST: <expected_behavior>
  -- ===========================================================================
  procedure <expected_behavior>
  is
    l_result varchar2(4000 char);
  begin
    -- Arrange: fixtures come from seed_fixtures.

    -- Act
    l_result := prefix_<module>_api.get_<entity>_name(
                    p_<entity>_id                       => <fixture_id>
                );

    -- Assert
    ut.expect(l_result).to_equal(gc_marker || ' active row');
  end <expected_behavior>;








  -- ===========================================================================
  -- TEST: <raises_when_condition>
  -- ===========================================================================
  -- --%throws(-20001) on the spec makes the test pass only if this raises it.
  procedure <raises_when_condition>
  is
  begin
    prefix_<module>_api.create_<entity>(
        p_<column_1>                                => null
    );
  end <raises_when_condition>;








  -- ===========================================================================
  -- TEST: <regression_ticket_behavior>
  -- ===========================================================================
  /**
   * <TICKET>: <one line on the bug this guards against>. Uses the nested
   * block instead of --%throws because the message must be checked too.
   */
  procedure <regression_ticket_behavior>
  is
  begin
    begin
      prefix_<module>_api.<unit_under_test>(
          p_<column_1>                              => '<input that used to break it>'
      );
      ut.fail('Expected <unit_under_test> to raise for <condition>.');
    exception
      when others then
        ut.expect(sqlcode).to_equal(-20001);
        ut.expect(sqlerrm).not_to_be_like('%<internal detail that must not leak>%');
    end;
  end <regression_ticket_behavior>;

end ut_prefix_<area>;
/
