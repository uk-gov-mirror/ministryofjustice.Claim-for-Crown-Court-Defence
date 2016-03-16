require Rails.root.join('db','seed_helper')

[
  'Conference and view - car',
  'Conference and view - hotel stay',
  'Conference and view - train',
  'Conference and view - travel time',
  'Travel and hotel - car',
  'Travel and hotel - conference and view',
  'Travel and hotel - hotel stay',
  'Travel and hotel - train',
].each do |expense_type_name|
  SeedHelper.find_or_create_expense_type!(name: expense_type_name, roles: ['agfs'])
end
