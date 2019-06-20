entity test is
  generic (
    test: boolean := false;
  );
end test;

architecture behav of test is
begin
end behav;

library work;
use work.test_pkg.all;

entity test_tc is
end test_tc;

architecture behav of test_tc is
begin
  uut: test generic map (test => true);
end behav;
