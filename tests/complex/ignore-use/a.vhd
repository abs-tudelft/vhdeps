
-- pragma vhdeps ignore package x
library work;
use work.x.all;

entity a is
end a;

architecture struct of a is
begin

  -- pragma vhdeps ignore entity b
  b_inst: entity work.b;

  -- pragma vhdeps ignore component c
  c_inst: c generic map (x => 1);

end struct;
