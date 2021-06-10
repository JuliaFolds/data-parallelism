# This file was generated, do not modify it. # hide
sdpl(*′, +′) = ((a₁, b₁), (a₂, b₂)) -> (a₁ *′ a₂, b₁ +′ (a₁ *′ b₂))
sdpr(*′, +′) = ((a₁, b₁), (a₂, b₂)) -> (a₁ *′ a₂, (b₁ *′ a₂) +′ b₂)