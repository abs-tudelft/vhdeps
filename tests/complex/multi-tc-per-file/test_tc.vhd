--pragma simulation timeout 1 ms

entity foo_tc is
end foo_tc;

architecture behav of foo_tc is
begin
  report_proc: process is
  begin
    wait for 10 ns;
    report "working!" severity note;
    wait;
  end process;
end behav;

entity bar_tc is
end bar_tc;

architecture behav of bar_tc is
begin
  report_proc: process is
  begin
    wait for 10 ns;
    report "working!" severity note;
    wait;
  end process;
end behav;

entity baz is
end baz;

architecture behav of baz is
begin
  report_proc: process is
  begin
    wait for 10 ns;
    report "working!" severity note;
    wait;
  end process;
end behav;
