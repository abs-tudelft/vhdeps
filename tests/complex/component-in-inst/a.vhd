entity a is
end a;

architecture struct of a is
  component b is
  end b;
begin
  b_inst: component b port map;
end struct;
