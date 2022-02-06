all:
	convert +append red.png green.png blue.png yellow.png row1.png
	convert +append empty.png bomb.png explosion.png row2.png
	#convert -append row1.png row2.png brickwall.png allrows.png
	convert -append row1.png brickwall.png allrows.png
	convert allrows.png PNG8:allrows-indexed.png
	#convert allrows-indexed.png -crop 1x3@ tiles%d.png
	mv allrows-indexed.png ../img-src/tiles.png
