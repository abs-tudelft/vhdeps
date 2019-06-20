entity test is
end test;

architecture behav of test is
begin
  missing_inst: missing generic map (really_missing => "yes");
end behav;
