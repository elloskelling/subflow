import cv2

def RGB2char(rgbtuple):
    red = round(rgbtuple[2]/255.*3.)
    green = round(rgbtuple[1]/255.*3.)
    blue = round(rgbtuple[0]/255.*3.)
    color = (red << 4) | (green << 2) | blue
    return color

def Life2CodingRGB(event, x, y, flags, param):
    if event == cv2.EVENT_MOUSEMOVE :  # checks mouse moves
        colorsBGR = image[y, x]
        print("Color code: {} ".format(RGB2char(colorsBGR)))


# Read an image
image = cv2.imread("palette.png")

# Create a window and set Mousecallback to a function for that window
cv2.namedWindow('Life2CodingRGB')
cv2.setMouseCallback('Life2CodingRGB', Life2CodingRGB)

# Do until esc pressed
while (1):
    cv2.imshow('Life2CodingRGB', image)
    if cv2.waitKey(10) & 0xFF == 27:
        break

# if esc is pressed, close all windows.
cv2.destroyAllWindows()