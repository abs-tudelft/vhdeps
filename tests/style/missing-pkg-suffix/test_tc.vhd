library work;
use work.test_pk.all;

entity test_tc is
end test_tc;

architecture behav of test_tc is
begin
  uut: test generic map (test => true);
end behav;
