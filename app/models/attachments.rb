# Image sizes for files embedded in rich text, as Fizzy has them.
module Attachments
  VARIANTS = {
    small: { loader: { n: -1 }, resize_to_limit: [ 800, 600 ] },
    large: { loader: { n: -1 }, resize_to_limit: [ 1024, 768 ] }
  }.freeze
end
