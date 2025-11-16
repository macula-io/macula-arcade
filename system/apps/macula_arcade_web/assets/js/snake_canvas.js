/**
 * Snake Canvas Rendering Hook
 *
 * Renders the Snake game state on HTML5 Canvas
 * Updates in real-time as game state changes
 */

const CELL_SIZE = 20;
const GRID_WIDTH = 40;
const GRID_HEIGHT = 30;

const COLORS = {
  background: '#1a1a2e',
  grid: '#16213e',
  player1: '#0f3460',
  player2: '#e94560',
  food: '#ffd700'
};

export const SnakeCanvas = {
  mounted() {
    this.canvas = this.el;
    this.ctx = this.canvas.getContext('2d');

    // Set canvas size
    this.canvas.width = GRID_WIDTH * CELL_SIZE;
    this.canvas.height = GRID_HEIGHT * CELL_SIZE;

    // Initial render
    this.render();

    // Watch for state changes
    this.handleEvent("game_state_update", ({game_state}) => {
      this.gameState = game_state;
      this.render();
    });
  },

  updated() {
    // Get game state from data attribute
    const gameStateJson = this.el.getAttribute('data-game-state');
    if (gameStateJson) {
      try {
        this.gameState = JSON.parse(gameStateJson);
        this.render();
      } catch (e) {
        console.error('Failed to parse game state:', e);
      }
    }
  },

  render() {
    if (!this.gameState) {
      this.renderEmpty();
      return;
    }

    const ctx = this.ctx;

    // Clear canvas
    ctx.fillStyle = COLORS.background;
    ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    // Draw grid
    this.drawGrid();

    // Draw food
    if (this.gameState.food_position) {
      this.drawFood(this.gameState.food_position);
    }

    // Draw snakes
    if (this.gameState.player1_snake) {
      this.drawSnake(this.gameState.player1_snake, COLORS.player1);
    }

    if (this.gameState.player2_snake) {
      this.drawSnake(this.gameState.player2_snake, COLORS.player2);
    }
  },

  renderEmpty() {
    const ctx = this.ctx;
    ctx.fillStyle = COLORS.background;
    ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    ctx.fillStyle = '#fff';
    ctx.font = '24px Arial';
    ctx.textAlign = 'center';
    ctx.fillText('Waiting for game...', this.canvas.width / 2, this.canvas.height / 2);
  },

  drawGrid() {
    const ctx = this.ctx;
    ctx.strokeStyle = COLORS.grid;
    ctx.lineWidth = 1;

    // Vertical lines
    for (let x = 0; x <= GRID_WIDTH; x++) {
      ctx.beginPath();
      ctx.moveTo(x * CELL_SIZE, 0);
      ctx.lineTo(x * CELL_SIZE, this.canvas.height);
      ctx.stroke();
    }

    // Horizontal lines
    for (let y = 0; y <= GRID_HEIGHT; y++) {
      ctx.beginPath();
      ctx.moveTo(0, y * CELL_SIZE);
      ctx.lineTo(this.canvas.width, y * CELL_SIZE);
      ctx.stroke();
    }
  },

  drawSnake(snake, color) {
    const ctx = this.ctx;

    snake.forEach(([x, y], index) => {
      // Head is brighter
      if (index === 0) {
        ctx.fillStyle = this.lightenColor(color, 40);
      } else {
        ctx.fillStyle = color;
      }

      ctx.fillRect(
        x * CELL_SIZE + 1,
        y * CELL_SIZE + 1,
        CELL_SIZE - 2,
        CELL_SIZE - 2
      );

      // Add eyes to head
      if (index === 0) {
        ctx.fillStyle = '#fff';
        ctx.beginPath();
        ctx.arc(x * CELL_SIZE + 6, y * CELL_SIZE + 6, 2, 0, Math.PI * 2);
        ctx.fill();
        ctx.beginPath();
        ctx.arc(x * CELL_SIZE + 14, y * CELL_SIZE + 6, 2, 0, Math.PI * 2);
        ctx.fill();
      }
    });
  },

  drawFood([x, y]) {
    const ctx = this.ctx;
    ctx.fillStyle = COLORS.food;

    // Draw as a circle
    ctx.beginPath();
    ctx.arc(
      x * CELL_SIZE + CELL_SIZE / 2,
      y * CELL_SIZE + CELL_SIZE / 2,
      CELL_SIZE / 2 - 2,
      0,
      Math.PI * 2
    );
    ctx.fill();
  },

  lightenColor(color, percent) {
    const num = parseInt(color.replace("#", ""), 16);
    const amt = Math.round(2.55 * percent);
    const R = (num >> 16) + amt;
    const G = (num >> 8 & 0x00FF) + amt;
    const B = (num & 0x0000FF) + amt;
    return "#" + (
      0x1000000 +
      (R < 255 ? (R < 1 ? 0 : R) : 255) * 0x10000 +
      (G < 255 ? (G < 1 ? 0 : G) : 255) * 0x100 +
      (B < 255 ? (B < 1 ? 0 : B) : 255)
    ).toString(16).slice(1);
  }
};
