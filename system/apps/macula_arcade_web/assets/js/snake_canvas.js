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
    this.fireworks = [];
    this.particles = [];
    this.effectStarted = false;
    this.playerId = this.el.getAttribute('data-player-id');

    // Set canvas size
    this.canvas.width = GRID_WIDTH * CELL_SIZE;
    this.canvas.height = GRID_HEIGHT * CELL_SIZE;

    // Read initial game state from data attribute
    const gameStateJson = this.el.getAttribute('data-game-state');
    if (gameStateJson) {
      try {
        this.gameState = JSON.parse(gameStateJson);
      } catch (e) {
        console.error('Failed to parse initial game state:', e);
      }
    }

    // Initial render
    this.render();

    // Watch for state changes
    this.handleEvent("game_state_update", ({game_state}) => {
      this.gameState = game_state;

      // Start effect when game finishes
      if (game_state.game_status === 'finished' && !this.effectStarted) {
        this.effectStarted = true;
        const isWinner = game_state.winner === this.playerId;
        if (isWinner) {
          this.startFireworks();
        } else {
          this.startGraveyard();
        }
      }

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
  },

  // Fireworks effect for winner celebration
  startFireworks() {
    const colors = ['#ff0000', '#00ff00', '#0000ff', '#ffff00', '#ff00ff', '#00ffff', '#ffd700', '#ff6b6b'];
    let frameCount = 0;
    const maxFrames = 180; // 3 seconds at 60fps

    const animate = () => {
      if (frameCount >= maxFrames) {
        this.particles = [];
        this.render();
        return;
      }

      // Launch new fireworks randomly
      if (Math.random() < 0.15) {
        const x = Math.random() * this.canvas.width;
        const y = Math.random() * (this.canvas.height * 0.6);
        const color = colors[Math.floor(Math.random() * colors.length)];
        this.createExplosion(x, y, color);
      }

      // Update particles
      this.particles = this.particles.filter(p => {
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.05; // gravity
        p.life -= 0.02;
        return p.life > 0;
      });

      // Render game and particles
      this.render();
      this.drawParticles();

      frameCount++;
      requestAnimationFrame(animate);
    };

    animate();
  },

  createExplosion(x, y, color) {
    const particleCount = 30;
    for (let i = 0; i < particleCount; i++) {
      const angle = (Math.PI * 2 * i) / particleCount;
      const speed = 2 + Math.random() * 3;
      this.particles.push({
        x: x,
        y: y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        color: color,
        life: 1.0,
        size: 2 + Math.random() * 2
      });
    }
  },

  drawParticles() {
    const ctx = this.ctx;
    this.particles.forEach(p => {
      ctx.globalAlpha = p.life;
      ctx.fillStyle = p.color;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
      ctx.fill();
    });
    ctx.globalAlpha = 1.0;
  },

  // Graveyard effect for loser
  startGraveyard() {
    this.tombstones = [];
    this.ghosts = [];
    let frameCount = 0;
    const maxFrames = 180;

    // Create tombstones
    for (let i = 0; i < 5; i++) {
      this.tombstones.push({
        x: 100 + i * 140,
        y: this.canvas.height - 80,
        width: 40,
        height: 60,
        opacity: 0
      });
    }

    // Create floating ghosts
    for (let i = 0; i < 8; i++) {
      this.ghosts.push({
        x: Math.random() * this.canvas.width,
        y: Math.random() * this.canvas.height,
        size: 15 + Math.random() * 10,
        vx: (Math.random() - 0.5) * 2,
        vy: -0.5 - Math.random(),
        opacity: 0.3 + Math.random() * 0.4
      });
    }

    const animate = () => {
      if (frameCount >= maxFrames) {
        this.tombstones = [];
        this.ghosts = [];
        this.render();
        return;
      }

      // Fade in tombstones
      this.tombstones.forEach(t => {
        if (t.opacity < 1) t.opacity += 0.02;
      });

      // Move ghosts
      this.ghosts.forEach(g => {
        g.x += g.vx;
        g.y += g.vy;
        // Wrap around
        if (g.y < -20) g.y = this.canvas.height + 20;
        if (g.x < -20) g.x = this.canvas.width + 20;
        if (g.x > this.canvas.width + 20) g.x = -20;
      });

      this.render();
      this.drawGraveyard();

      frameCount++;
      requestAnimationFrame(animate);
    };

    animate();
  },

  drawGraveyard() {
    const ctx = this.ctx;

    // Dark overlay - lighter to keep game visible
    ctx.fillStyle = 'rgba(0, 0, 0, 0.2)';
    ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    // Draw tombstones
    if (this.tombstones) {
      this.tombstones.forEach(t => {
        ctx.globalAlpha = t.opacity;

        // Tombstone body
        ctx.fillStyle = '#4a4a4a';
        ctx.fillRect(t.x, t.y, t.width, t.height);

        // Tombstone top (rounded)
        ctx.beginPath();
        ctx.arc(t.x + t.width/2, t.y, t.width/2, Math.PI, 0);
        ctx.fill();

        // RIP text
        ctx.fillStyle = '#888';
        ctx.font = '12px Arial';
        ctx.textAlign = 'center';
        ctx.fillText('RIP', t.x + t.width/2, t.y + 35);
      });
    }

    // Draw ghosts
    if (this.ghosts) {
      this.ghosts.forEach(g => {
        ctx.globalAlpha = g.opacity;
        ctx.fillStyle = '#ffffff';

        // Ghost body
        ctx.beginPath();
        ctx.arc(g.x, g.y, g.size, Math.PI, 0);
        ctx.lineTo(g.x + g.size, g.y + g.size);
        // Wavy bottom
        for (let i = 0; i < 3; i++) {
          const waveX = g.x + g.size - (i + 1) * (g.size * 2 / 3);
          ctx.quadraticCurveTo(waveX + g.size/6, g.y + g.size + 5, waveX, g.y + g.size);
        }
        ctx.closePath();
        ctx.fill();

        // Eyes
        ctx.fillStyle = '#000';
        ctx.beginPath();
        ctx.arc(g.x - g.size/3, g.y - 2, 3, 0, Math.PI * 2);
        ctx.arc(g.x + g.size/3, g.y - 2, 3, 0, Math.PI * 2);
        ctx.fill();
      });
    }

    ctx.globalAlpha = 1.0;
  }
};
