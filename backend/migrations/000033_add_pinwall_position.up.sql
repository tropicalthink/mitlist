-- Persist each pinwall note's position on the shared cork board so a member's
-- move is remembered and syncs to everyone. Coordinates are in the board's
-- fixed logical space (see _kBoardW/_kBoardH on the client); NULL means the
-- note has never been placed and the client lays it out on its grid.
ALTER TABLE pinwall_posts ADD COLUMN pos_x DOUBLE PRECISION;
ALTER TABLE pinwall_posts ADD COLUMN pos_y DOUBLE PRECISION;
