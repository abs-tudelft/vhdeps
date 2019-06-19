--pragma simulation timeout 1 ms

entity test_tc is
end test_tc;

architecture behav of test_tc is
begin
  report_proc: process is
    function breaks return natural is
      variable test: natural := 10;
    begin
      for i in 1 to 20 loop
        test := test - 1;
      end loop;
      return test;
    end function;
    constant broken: string(1 to breaks) := (others => 'a');
  begin
    wait for 10 ns;
    report "huh" severity note;
    wait;
  end process;
end behav;
